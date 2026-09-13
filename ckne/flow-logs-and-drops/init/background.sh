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
    matchLabels: {app: api, tier: backend}
  template:
    metadata:
      labels: {app: api, tier: backend}
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
# The legitimate caller.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels: {app: web, tier: frontend}
  template:
    metadata:
      labels: {app: web, tier: frontend}
    spec:
      containers:
      - name: web
        image: registry.k8s.io/e2e-test-images/agnhost:2.53
        command: ["/bin/sh","-c","while true; do wget -q -T3 -O /dev/null http://api/hostname 2>/dev/null; sleep 2; done"]
---
# Something nobody authorised, talking to the same backend. It is here from
# the start, which is the point: it shows up in the flow log before anyone
# thinks to look for it.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanner
spec:
  replicas: 1
  selector:
    matchLabels: {app: scanner}
  template:
    metadata:
      labels: {app: scanner}
    spec:
      containers:
      - name: scanner
        image: registry.k8s.io/e2e-test-images/agnhost:2.53
        command: ["/bin/sh","-c","while true; do wget -q -T3 -O /dev/null http://api/ 2>/dev/null; sleep 3; done"]
---
apiVersion: v1
kind: Pod
metadata:
  name: cli
  labels: {app: cli}
spec:
  containers:
  - name: cli
    image: registry.k8s.io/e2e-test-images/agnhost:2.53
    command: ["/bin/sh","-c","sleep infinity"]
EOF

kubectl rollout status deployment/api --timeout=240s >/dev/null 2>&1
kubectl rollout status deployment/web --timeout=240s >/dev/null 2>&1
kubectl rollout status deployment/scanner --timeout=240s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod/cli --timeout=240s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# hubble lives inside the Cilium agent. Relay is only needed to aggregate
# across nodes -- on one node the agent's own buffer has everything, which is
# why this lab needs nothing installed.
cat > /usr/local/bin/flows <<'WRAP'
#!/bin/bash
kubectl -n kube-system exec ds/cilium -c cilium-agent -- hubble observe "$@" 2>/dev/null
WRAP
chmod +x /usr/local/bin/flows

# One request from cli to the api Service, reporting the HTTP code. 000 means
# nothing answered at all -- the signature of an L3/L4 drop.
cat > /usr/local/bin/apicall <<'WRAP'
#!/bin/bash
PATH_=${1:-/hostname}
# curl exits non-zero on a timeout, but -w has already printed 000 by then,
# so do not add a fallback echo -- it would print a second, duplicate line.
kubectl exec cli -- curl -s -m 6 -o /dev/null -w "GET ${PATH_} -> %{http_code}\n" "http://api${PATH_}" 2>/dev/null
exit 0
WRAP
chmod +x /usr/local/bin/apicall

touch /tmp/.initfinished
