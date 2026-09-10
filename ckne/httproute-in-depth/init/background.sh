#!/bin/bash

EG_VERSION=v1.2.6

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash /tmp/get_helm.sh >/dev/null 2>&1
fi

for IMG in registry.k8s.io/e2e-test-images/agnhost:2.53 "docker.io/envoyproxy/gateway:${EG_VERSION}"; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 \
    || crictl pull "$IMG" >/dev/null 2>&1 \
    || true
done

# Envoy Gateway ships its own copy of the Gateway API CRDs inside the Helm
# chart. Installing them separately first causes a field-manager conflict on
# `helm install`, so this is the only step that touches the CRDs -- the
# chart owns them.
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "$EG_VERSION" \
  --namespace envoy-gateway-system --create-namespace \
  --wait --timeout 5m >/dev/null 2>&1

cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-canary
  template:
    metadata:
      labels:
        app: web-canary
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
  name: web-canary
spec:
  selector:
    app: web-canary
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-b
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: team-b
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
  namespace: team-b
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
kubectl rollout status deployment/web-canary --timeout=180s >/dev/null 2>&1
kubectl -n team-b rollout status deployment/web --timeout=180s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod/client --timeout=180s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The Service in front of whichever Envoy Pod is currently serving a Gateway.
# Envoy Gateway names it after the Gateway, with a generation-specific hash
# suffix that changes if the Gateway's spec changes significantly -- looking
# it up dynamically avoids hardcoding a name that could go stale.
cat > /usr/local/bin/gwaddr <<'WRAP'
#!/bin/bash
GATEWAY=${1:-web-gateway}
NS=${2:-default}
kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace="$NS",gateway.envoyproxy.io/owning-gateway-name="$GATEWAY" \
  -o jsonpath='{.items[0].spec.clusterIP}'
WRAP
chmod +x /usr/local/bin/gwaddr

# One request through the Gateway, with a Host header and any extra headers
# given as NAME=VALUE pairs, printing which backend Pod answered.
cat > /usr/local/bin/routecheck <<'WRAP'
#!/bin/bash
HOST=$1
shift
GWIP=$(gwaddr)
[ -z "$GWIP" ] && { echo "no Gateway address yet"; exit 1; }

ARGS=(--header "Host: $HOST")
for KV in "$@"; do
  ARGS+=(--header "${KV%%=*}: ${KV#*=}")
done

kubectl exec client -- wget -qO- -T5 "${ARGS[@]}" "http://$GWIP/hostname" 2>&1
echo
WRAP
chmod +x /usr/local/bin/routecheck

touch /tmp/.initfinished
