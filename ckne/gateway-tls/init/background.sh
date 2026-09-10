#!/bin/bash

EG_VERSION=v1.2.6
CM_VERSION=v1.20.3

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash /tmp/get_helm.sh >/dev/null 2>&1
fi

for IMG in \
  registry.k8s.io/e2e-test-images/agnhost:2.53 \
  docker.io/library/nginx:1.27-alpine \
  "docker.io/envoyproxy/gateway:${EG_VERSION}" ; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 \
    || crictl pull "$IMG" >/dev/null 2>&1 \
    || true
done

helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1
helm repo update jetstack >/dev/null 2>&1

# Envoy Gateway bundles its own copy of the Gateway API CRDs and owns them via
# its Helm release -- applying them separately first causes a field-manager
# conflict on install.
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "$EG_VERSION" \
  --namespace envoy-gateway-system --create-namespace \
  --wait --timeout 5m >/dev/null 2>&1

helm install cert-manager jetstack/cert-manager \
  --version "$CM_VERSION" \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
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
EOF

# A self-signed root, playing the part of the organisation's internal CA --
# the same shape as a real one, minus a real root of trust to hand out.
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: self-signed-ca-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cluster-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: lab-root-ca
  secretName: cluster-ca-secret
  duration: 8760h
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: self-signed-ca-issuer
    kind: ClusterIssuer
EOF

kubectl wait --for=condition=Ready certificate/cluster-ca -n cert-manager --timeout=120s >/dev/null 2>&1

cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lab-ca-issuer
spec:
  ca:
    secretName: cluster-ca-secret
EOF

kubectl get secret cluster-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > /root/ca.crt

# A certificate this backend terminates itself with, independently of
# anything a Gateway listener will ever reference -- what a Passthrough
# listener in step 4 has to route to.
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: pass-cert
spec:
  secretName: pass-cert-tls
  dnsNames:
  - pass.example.com
  issuerRef:
    name: lab-ca-issuer
    kind: ClusterIssuer
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tls-backend-conf
data:
  default.conf: |
    server {
        listen 8443 ssl;
        ssl_certificate     /tls/tls.crt;
        ssl_certificate_key /tls/tls.key;
        location / {
            return 200 "tls-backend\n";
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tls-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tls-backend
  template:
    metadata:
      labels:
        app: tls-backend
    spec:
      containers:
      - name: tls-backend
        image: nginx:1.27-alpine
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: tls
          mountPath: /tls
        - name: conf
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: tls
        secret:
          secretName: pass-cert-tls
      - name: conf
        configMap:
          name: tls-backend-conf
---
apiVersion: v1
kind: Service
metadata:
  name: tls-backend
spec:
  selector:
    app: tls-backend
  ports:
  - port: 8443
    targetPort: 8443
EOF

kubectl wait --for=condition=Ready certificate/pass-cert --timeout=60s >/dev/null 2>&1

kubectl rollout status deployment/web --timeout=180s >/dev/null 2>&1
kubectl rollout status deployment/web-canary --timeout=180s >/dev/null 2>&1
kubectl rollout status deployment/tls-backend --timeout=180s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The Envoy Service fronting whichever Gateway this lab is using.
cat > /usr/local/bin/gwaddr <<'WRAP'
#!/bin/bash
GATEWAY=${1:-web-gateway}
NS=${2:-default}
kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace="$NS",gateway.envoyproxy.io/owning-gateway-name="$GATEWAY" \
  -o jsonpath='{.items[0].spec.clusterIP}'
WRAP
chmod +x /usr/local/bin/gwaddr

# The certificate actually being served for one SNI name, on one port --
# no request made, just the TLS handshake and the leaf certificate it offers.
cat > /usr/local/bin/servedcert <<'WRAP'
#!/bin/bash
SNI=$1
PORT=${2:-443}
[ -z "$SNI" ] && { echo "usage: servedcert <sni-name> [port]"; exit 1; }
GWIP=$(gwaddr)
echo | timeout 5 openssl s_client -connect "$GWIP:$PORT" -servername "$SNI" 2>/dev/null \
  | openssl x509 -noout -issuer -ext subjectAltName -serial
WRAP
chmod +x /usr/local/bin/servedcert

# An HTTPS request through the Gateway, verified against the lab's CA, with
# the hostname resolved straight to the Gateway's address.
cat > /usr/local/bin/securecurl <<'WRAP'
#!/bin/bash
HOST=$1
PORT=${2:-443}
[ -z "$HOST" ] && { echo "usage: securecurl <hostname> [port]"; exit 1; }
GWIP=$(gwaddr)
curl -s --cacert /root/ca.crt --resolve "$HOST:$PORT:$GWIP" "https://$HOST:$PORT/hostname"
echo
WRAP
chmod +x /usr/local/bin/securecurl

touch /tmp/.initfinished
