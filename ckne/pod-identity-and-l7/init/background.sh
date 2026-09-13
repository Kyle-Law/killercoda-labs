#!/bin/bash

ctr -n k8s.io images pull registry.k8s.io/e2e-test-images/agnhost:2.53 >/dev/null 2>&1 \
  || crictl pull registry.k8s.io/e2e-test-images/agnhost:2.53 >/dev/null 2>&1 || true

cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 1
  selector:
    matchLabels: {app: api}
  template:
    metadata:
      labels: {app: api}
    spec:
      containers:
      - name: api
        image: registry.k8s.io/e2e-test-images/agnhost:2.53
        args: ["netexec","--http-port=8080"]
        ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector: {app: api}
  ports: [{port: 80, targetPort: 8080}]
---
# The authorised caller. A Deployment, not a bare Pod, so rescheduling it in
# step 4 is a single command.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: web
        image: registry.k8s.io/e2e-test-images/agnhost:2.53
        command: ["/bin/sh","-c","sleep infinity"]
EOF

kubectl rollout status deployment/api --timeout=240s >/dev/null 2>&1
kubectl rollout status deployment/web --timeout=240s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# One request from web to the api Service. 000 means nothing answered -- an
# L3/L4 drop. A 403 means something answered and refused -- an L7 decision.
# Telling those two apart by eye is most of this lab.
cat > /usr/local/bin/try <<'WRAP'
#!/bin/bash
METHOD=${1:-GET}
URLPATH=${2:-/hostname}
POD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -z "$POD" ] && { echo "no running web pod"; exit 1; }
if [ "$METHOD" = "GET" ]; then
  kubectl exec "$POD" -- curl -s -m 6 -o /dev/null \
    -w "${METHOD} ${URLPATH} -> %{http_code}\n" "http://api${URLPATH}" 2>/dev/null
else
  kubectl exec "$POD" -- curl -s -m 6 -o /dev/null -X "$METHOD" --data '' \
    -w "${METHOD} ${URLPATH} -> %{http_code}\n" "http://api${URLPATH}" 2>/dev/null
fi
exit 0
WRAP
chmod +x /usr/local/bin/try

# What Cilium thinks about the api endpoint: whether policy is enforced, the
# identity it resolved, and -- once an L7 rule exists -- the proxy redirect.
cat > /usr/local/bin/apistate <<'WRAP'
#!/bin/bash
echo "=== api endpoint ==="
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  cilium-dbg endpoint list 2>/dev/null | grep -E 'ENDPOINT|app=api'
echo
echo "=== proxy redirects ==="
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  cilium-dbg status --verbose 2>/dev/null | grep -A3 'Proxy Status'
WRAP
chmod +x /usr/local/bin/apistate

# Mean request latency over N samples, for measuring what the L7 proxy costs.
cat > /usr/local/bin/latency <<'WRAP'
#!/bin/bash
N=${1:-40}
POD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -z "$POD" ] && { echo "no running web pod"; exit 1; }
kubectl exec "$POD" -- /bin/sh -c \
  "for i in \$(seq 1 $N); do curl -s -o /dev/null -w '%{time_total}\n' http://api/hostname; done" 2>/dev/null \
  | sort -n | awk -v n="$N" '{a[NR]=$1; s+=$1} END{printf "  %d requests: mean %.4fs  median %.4fs\n", NR, s/NR, a[int(NR/2)]}'
WRAP
chmod +x /usr/local/bin/latency

touch /tmp/.initfinished
