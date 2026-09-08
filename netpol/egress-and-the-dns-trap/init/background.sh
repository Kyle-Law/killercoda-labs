#!/bin/bash

ctr -n k8s.io images pull docker.io/stefanprodan/podinfo:6.6.0 >/dev/null 2>&1 \
  || crictl pull docker.io/stefanprodan/podinfo:6.6.0 >/dev/null 2>&1 \
  || true

kubectl create namespace shop >/dev/null 2>&1

for app in web api; do
cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app
  namespace: shop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app
  template:
    metadata:
      labels:
        app: $app
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.6.0
        env:
        - name: PODINFO_UI_MESSAGE
          value: "$app"
        ports:
        - containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: $app
  namespace: shop
spec:
  selector:
    app: $app
  ports:
  - port: 9898
    targetPort: 9898
EOF
done

# Finds a Pod belonging to a Deployment that's actually Running and not on
# its way out -- avoids picking a terminating Pod right after a rollout.
webpod() {
  kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }'
}

# Resolves a hostname from inside web -- shows exactly what a real
# application's DNS lookup sees, success or failure.
cat > /usr/local/bin/dnscheck <<'WRAP'
#!/bin/bash
HOST=${1:-api.shop.svc.cluster.local}
POD=$(kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
  | awk -F'|' '$2 == "" { print $1; exit }')
[ -z "$POD" ] && { echo "no running web pod"; exit 1; }
kubectl -n shop exec "$POD" -- nslookup "$HOST" 2>&1
WRAP
chmod +x /usr/local/bin/dnscheck

# The real request web makes: HTTP to api, by name. This is what "the app"
# is actually doing every time in this lab.
cat > /usr/local/bin/apicall <<'WRAP'
#!/bin/bash
POD=$(kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
  | awk -F'|' '$2 == "" { print $1; exit }')
[ -z "$POD" ] && { echo "no running web pod"; exit 1; }
kubectl -n shop exec "$POD" -- wget -q -T 4 -O- http://api:9898/ 2>&1
RC=$?
echo
echo "exit code: $RC"
WRAP
chmod +x /usr/local/bin/apicall

# The same request, but straight to api's ClusterIP -- resolved here, from
# outside the Pod, so it never asks web's own DNS to do anything. Useful for
# telling "DNS is broken" apart from "the connection itself is blocked".
cat > /usr/local/bin/rawcall <<'WRAP'
#!/bin/bash
POD=$(kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
  | awk -F'|' '$2 == "" { print $1; exit }')
[ -z "$POD" ] && { echo "no running web pod"; exit 1; }
IP=$(kubectl -n shop get svc api -o jsonpath='{.spec.clusterIP}')
echo "api's ClusterIP: $IP"
kubectl -n shop exec "$POD" -- wget -q -T 4 -O- "http://$IP:9898/" 2>&1
RC=$?
echo
echo "exit code: $RC"
WRAP
chmod +x /usr/local/bin/rawcall

# TCP-probes one ip:port from web, and prints the raw signal: "refused"
# means the packet got there and nothing answered; "timed out" means
# something dropped it silently in transit. That distinction is the whole
# tool for telling "policy let this through" from "policy is blocking this",
# independent of whether anything is actually listening on the far end.
cat > /usr/local/bin/portcheck <<'WRAP'
#!/bin/bash
IP=$1
PORT=$2
if [ -z "$IP" ] || [ -z "$PORT" ]; then
  echo "usage: portcheck <ip> <port>"
  exit 1
fi
POD=$(kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
  | awk -F'|' '$2 == "" { print $1; exit }')
[ -z "$POD" ] && { echo "no running web pod"; exit 1; }
kubectl -n shop exec "$POD" -- nc -zv -w 3 "$IP" "$PORT" 2>&1
WRAP
chmod +x /usr/local/bin/portcheck

# Finds a Pod in kube-system that (a) is not CoreDNS and (b) has its own Pod
# IP rather than the node's -- hostNetwork pods (often the control-plane
# static Pods) sit outside NetworkPolicy's normal pod-IP model and would
# make a poor, CNI-inconsistent target for this demonstration. Picks
# whatever the cluster actually has rather than naming a CNI-specific Pod.
cat > /usr/local/bin/kubesystempeer <<'WRAP'
#!/bin/bash
kubectl -n kube-system get pods -o json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
node_ips = set()
try:
    nodes = json.loads(sys.argv[1])
    node_ips = {a['address'] for n in nodes['items'] for a in n['status'].get('addresses', []) if a['type'] == 'InternalIP'}
except Exception:
    pass
for p in d.get('items', []):
    labels = p['metadata'].get('labels', {})
    if labels.get('k8s-app') == 'kube-dns':
        continue
    if p['spec'].get('hostNetwork'):
        continue
    ip = p['status'].get('podIP')
    if ip and ip not in node_ips:
        print(ip)
        break
" "$(kubectl get nodes -o json 2>/dev/null)"
WRAP
chmod +x /usr/local/bin/kubesystempeer

kubectl -n shop rollout status deployment/web --timeout=180s >/dev/null 2>&1
kubectl -n shop rollout status deployment/api --timeout=180s >/dev/null 2>&1

touch /tmp/.initfinished
