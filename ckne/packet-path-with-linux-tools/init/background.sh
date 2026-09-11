#!/bin/bash

if ! command -v tcpdump >/dev/null 2>&1; then
  apt-get update >/dev/null 2>&1
  apt-get install -y --no-install-recommends tcpdump >/dev/null 2>&1
fi

for IMG in registry.k8s.io/e2e-test-images/agnhost:2.53; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 \
    || crictl pull "$IMG" >/dev/null 2>&1 \
    || true
done

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
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  labels:
    app: client
spec:
  containers:
  - name: client
    image: registry.k8s.io/e2e-test-images/agnhost:2.53
    command: ["/bin/sh", "-c", "sleep infinity"]
EOF

kubectl rollout status deployment/web --timeout=180s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod/client --timeout=180s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The host-side interface index a veth reports for itself has nothing to do
# with which network namespace it was created in -- kernels hand out ifindex
# numbers from one global counter. Inside a Pod's netns, eth0's *iflink* (its
# own concept of "the interface on the other end") is that same global number,
# projected from the host's side. Matching iflink against ifindex is what
# actually finds the peer -- it works for any CNI's veth naming, not just
# names starting with "veth".
cat > /usr/local/bin/podveth <<'WRAP'
#!/bin/bash
POD=$1
NS=${2:-default}
[ -z "$POD" ] && { echo "usage: podveth <pod> [namespace]"; exit 1; }

IFLINK=$(kubectl -n "$NS" exec "$POD" -- cat /sys/class/net/eth0/iflink 2>/dev/null)
[ -z "$IFLINK" ] && { echo "could not read iflink for $NS/$POD"; exit 1; }

for f in /sys/class/net/*/ifindex; do
  IDX=$(cat "$f" 2>/dev/null)
  if [ "$IDX" == "$IFLINK" ]; then
    basename "$(dirname "$f")"
    exit 0
  fi
done

echo "no host interface found with ifindex $IFLINK"
exit 1
WRAP
chmod +x /usr/local/bin/podveth

# Where a Service's translation actually lives depends on the datapath this
# cluster runs, and the two put it in completely different places. This dumps
# both sources so you can see which one is populated -- it does not tell you
# what that means for a packet capture, which is the point of step 3.
cat > /usr/local/bin/svctable <<'WRAP'
#!/bin/bash
SVC=${1:-web}
NS=${2:-default}
CLUSTER_IP=$(kubectl -n "$NS" get svc "$SVC" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
echo "Service $NS/$SVC has ClusterIP $CLUSTER_IP"
echo
echo "=== kube-proxy's iptables rules (nat table) ==="
if iptables-save -t nat 2>/dev/null | grep -q "$NS/$SVC"; then
  iptables-save -t nat | grep "$NS/$SVC"
else
  echo "  (none -- nothing in the nat table mentions $NS/$SVC)"
fi
echo
echo "=== Cilium's eBPF service map ==="
if kubectl -n kube-system get ds cilium >/dev/null 2>&1; then
  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    cilium-dbg service list 2>/dev/null | grep -E "Frontend|${CLUSTER_IP}" \
    || echo "  (cilium present but no entry found)"
else
  echo "  (no Cilium DaemonSet on this cluster)"
fi
WRAP
chmod +x /usr/local/bin/svctable

touch /tmp/.initfinished
