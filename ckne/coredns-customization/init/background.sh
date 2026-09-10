#!/bin/bash

COREDNS_IMAGE=$(kubectl -n kube-system get deploy coredns \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
COREDNS_IMAGE=${COREDNS_IMAGE:-registry.k8s.io/coredns/coredns:v1.11.3}

for IMG in registry.k8s.io/e2e-test-images/agnhost:2.53 "$COREDNS_IMAGE"; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 \
    || crictl pull "$IMG" >/dev/null 2>&1 \
    || true
done

# The application this cluster's DNS is expected to find.
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: registry.k8s.io/e2e-test-images/agnhost:2.53
        args: ["netexec", "--http-port=8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
EOF

# A second, entirely separate DNS server, standing in for the corporate
# resolver that owns a zone this cluster knows nothing about. It is authoritative
# for corp.internal and answers nothing else -- exactly like the internal
# resolver a real cluster has to be pointed at.
cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Namespace
metadata:
  name: corp-dns
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: corp-corefile
  namespace: corp-dns
data:
  Corefile: |
    corp.internal:53 {
        errors
        hosts {
            10.99.0.42 db.corp.internal
            10.99.0.43 mail.corp.internal
            fallthrough
        }
    }
    .:53 {
        errors
        health
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: corp-dns
  namespace: corp-dns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: corp-dns
  template:
    metadata:
      labels:
        app: corp-dns
    spec:
      containers:
      - name: coredns
        image: ${COREDNS_IMAGE}
        args: ["-conf", "/etc/coredns/Corefile"]
        volumeMounts:
        - name: config
          mountPath: /etc/coredns
      volumes:
      - name: config
        configMap:
          name: corp-corefile
---
apiVersion: v1
kind: Service
metadata:
  name: corp-dns
  namespace: corp-dns
spec:
  selector:
    app: corp-dns
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
EOF

# A permanent client to ask questions from. Every lookup in this lab is made
# from inside the cluster, because that is the only place cluster DNS exists.
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: dnstools
  labels:
    app: dnstools
spec:
  containers:
  - name: tools
    image: registry.k8s.io/e2e-test-images/agnhost:2.53
    command: ["/bin/sh", "-c", "sleep infinity"]
EOF

# The Corefile the learner edits, seeded from whatever this cluster is really
# running rather than a copy pasted into the lab text.
kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' > /root/Corefile 2>/dev/null
cp /root/Corefile /root/Corefile.original 2>/dev/null

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The Corefile CoreDNS is running right now, as opposed to whatever is sitting
# in /root/Corefile waiting to be applied.
cat > /usr/local/bin/corefile <<'WRAP'
#!/bin/bash
kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'
echo
WRAP
chmod +x /usr/local/bin/corefile

# Applies /root/Corefile and then waits for CoreDNS to actually pick it up,
# which is the part that surprises people: the ConfigMap update is instant, the
# reload is not. Reports the real elapsed time, and surfaces a rejected config
# rather than silently timing out.
cat > /usr/local/bin/applycorefile <<'WRAP'
#!/bin/bash
FILE=${1:-/root/Corefile}
[ -f "$FILE" ] || { echo "no such file: $FILE"; exit 1; }

# CoreDNS logs the SHA of the configuration it is running. Waiting for a SHA
# that differs from the current one is the only reliable signal: counting
# "Reloading complete" lines instead would finish early, because with two
# replicas the second Pod's reload of the *previous* config lands after the
# first Pod's, and looks exactly like a response to this change.
SHA_BEFORE=$(kubectl -n kube-system logs -l k8s-app=kube-dns --tail=-1 2>/dev/null \
  | grep "Running configuration SHA512" | tail -1 | awk '{print $NF}')

# Counted, not matched: CoreDNS never truncates its log, so an error from an
# earlier attempt in this same lab would be read as the outcome of this one.
BAD_BEFORE=$(kubectl -n kube-system logs -l k8s-app=kube-dns --tail=-1 2>/dev/null | grep -c "reload failed")

# A rejection is only believed once *every* replica has rejected it. One
# replica alone is ambiguous: when a broken config is replaced by a good one,
# the slower replica's complaint about the previous config arrives after this
# apply and is indistinguishable from a complaint about this one.
REPLICAS=$(kubectl -n kube-system get pods -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
[ "$REPLICAS" -lt 1 ] && REPLICAS=1

kubectl -n kube-system create configmap coredns --from-file=Corefile="$FILE" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || {
    echo "failed to update the ConfigMap"; exit 1; }

echo -n "ConfigMap updated. Waiting for CoreDNS to reload"
START=$(date +%s)
for _ in $(seq 1 24); do
  sleep 5
  echo -n "."
  LOGS=$(kubectl -n kube-system logs -l k8s-app=kube-dns --tail=-1 2>/dev/null)

  BAD_NOW=$(echo "$LOGS" | grep -c "reload failed")
  if [ "$BAD_NOW" -ge $(( BAD_BEFORE + REPLICAS )) ]; then
    echo " REJECTED after $(( $(date +%s) - START ))s"
    echo "$LOGS" | grep "reload failed" | tail -1
    echo
    echo "CoreDNS kept the last configuration that parsed. Cluster DNS is still up."
    exit 1
  fi

  # Every replica has to have converged, not just the first one. Returning as
  # soon as one Pod reloads leaves the other still answering from the old
  # config, and roughly half of the next lookups get the previous answer.
  SHAS=""
  CONVERGED=1
  for POD in $(kubectl -n kube-system get pods -l k8s-app=kube-dns \
                 --field-selector=status.phase=Running -o name 2>/dev/null); do
    POD_SHA=$(kubectl -n kube-system logs "$POD" --tail=-1 2>/dev/null \
      | grep "Running configuration SHA512" | tail -1 | awk '{print $NF}')
    if [ -z "$POD_SHA" ] || [ "$POD_SHA" == "$SHA_BEFORE" ]; then
      CONVERGED=0
      break
    fi
    SHAS="$SHAS $POD_SHA"
  done

  # They must also agree with each other. A Pod sitting on some older config
  # differs from SHA_BEFORE too, and would otherwise read as converged.
  [ "$(echo $SHAS | tr ' ' '\n' | sort -u | wc -l)" == "1" ] || CONVERGED=0

  if [ "$CONVERGED" == "1" ]; then
    echo " done in $(( $(date +%s) - START ))s"
    exit 0
  fi
done

# No reload and no rejection. The usual reason is that this file is identical
# to the configuration CoreDNS is already running -- which happens whenever a
# bad edit is reverted, since the revert restores exactly what the running Pods
# kept serving. Nothing to reload is a legitimate outcome, not a failure.
echo " no reload was triggered after $(( $(date +%s) - START ))s"
if [ "$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)" == "$(cat "$FILE")" ]; then
  echo "The ConfigMap matches this file and CoreDNS reported no error, so it was"
  echo "already running this configuration. Check the Pods rather than the log:"
  kubectl -n kube-system get pods -l k8s-app=kube-dns
  exit 0
fi
exit 1
WRAP
chmod +x /usr/local/bin/applycorefile

# One DNS question, asked from inside the cluster. Prints the answer, or the
# response code when there isn't one -- NXDOMAIN and SERVFAIL mean very
# different things and "it didn't work" hides the difference.
cat > /usr/local/bin/dnsq <<'WRAP'
#!/bin/bash
NAME=$1
SERVER=$2
[ -z "$NAME" ] && { echo "usage: dnsq <name> [dns-server-ip]"; exit 1; }

if [ -n "$SERVER" ]; then
  OUT=$(kubectl exec dnstools -- dig +short "@$SERVER" "$NAME" 2>/dev/null)
  FULL=$(kubectl exec dnstools -- dig "@$SERVER" "$NAME" 2>/dev/null)
  VIA=" (asking $SERVER directly)"
else
  OUT=$(kubectl exec dnstools -- dig +short "$NAME" 2>/dev/null)
  FULL=$(kubectl exec dnstools -- dig "$NAME" 2>/dev/null)
  VIA=""
fi

if [ -n "$OUT" ]; then
  echo "$NAME$VIA -> $OUT"
else
  STATUS=$(echo "$FULL" | awk '/->>HEADER<<-/{for(i=1;i<=NF;i++) if($i=="status:") print $(i+1)}' | tr -d ',')
  echo "$NAME$VIA -> no answer (status: ${STATUS:-no response})"
fi
WRAP
chmod +x /usr/local/bin/dnsq

# CoreDNS's own view of itself: are the Pods healthy, and what did the last
# configuration change do?
cat > /usr/local/bin/corednsstatus <<'WRAP'
#!/bin/bash
echo "=== CoreDNS Pods ==="
kubectl -n kube-system get pods -l k8s-app=kube-dns
echo
echo "=== recent reload activity ==="
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=-1 2>/dev/null \
  | grep -E "Reloading|reload failed|Error during parsing|plugin/reload" | tail -6
WRAP
chmod +x /usr/local/bin/corednsstatus

kubectl rollout status deployment/web --timeout=180s >/dev/null 2>&1
kubectl -n corp-dns rollout status deployment/corp-dns --timeout=180s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod/dnstools --timeout=180s >/dev/null 2>&1

touch /tmp/.initfinished
