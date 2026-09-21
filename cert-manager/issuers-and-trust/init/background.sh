#!/bin/bash

CM_VERSION=v1.20.3
TM_VERSION=v0.25.0

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash /tmp/get_helm.sh >/dev/null 2>&1
fi

for IMG in \
  docker.io/library/nginx:1.27-alpine \
  docker.io/curlimages/curl:8.11.1 ; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 \
    || crictl pull "$IMG" >/dev/null 2>&1 \
    || true
done

helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1
helm repo update jetstack >/dev/null 2>&1

helm install cert-manager jetstack/cert-manager \
  --version "$CM_VERSION" \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 5m >/dev/null 2>&1

# Installed now so step 4 is not half an install long. Nothing before step 4
# touches it.
helm install trust-manager jetstack/trust-manager \
  --version "$TM_VERSION" \
  --namespace cert-manager \
  --wait --timeout 5m >/dev/null 2>&1

if ! kubectl -n cert-manager get deploy cert-manager >/dev/null 2>&1; then
  touch /tmp/.initbroken
fi

kubectl create namespace pki >/dev/null 2>&1
kubectl create namespace app >/dev/null 2>&1
kubectl create namespace client >/dev/null 2>&1

# The starting position of step 1: a perfectly good Issuer owned by whoever
# runs `pki`, and a Certificate in `app` that names it and will never issue.
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: lab-selfsigned
  namespace: pki
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-cert
  namespace: app
spec:
  secretName: app-cert-tls
  dnsNames:
  - app.example.internal
  issuerRef:
    name: lab-selfsigned
    kind: Issuer
EOF

# Plumbing the learner applies rather than writes -- step 3 is about trust,
# not about nginx. The Secret named here is the one step 2 produces.
cat > /root/web.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-conf
  namespace: app
data:
  default.conf: |
    server {
        listen 8443 ssl;
        ssl_certificate     /tls/tls.crt;
        ssl_certificate_key /tls/tls.key;
        location / { return 200 "web, in namespace app\n"; }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: app
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
          secretName: web-cert-tls
      - name: conf
        configMap:
          name: web-conf
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: app
spec:
  selector:
    app: web
  ports:
  - port: 8443
    targetPort: 8443
EOF

# Step 4's consumer. It mounts the ConfigMap a Bundle has to create first, so
# it is applied in step 4 rather than here.
cat > /root/client.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
      - name: client
        image: curlimages/curl:8.11.1
        command: ["sleep", "infinity"]
        volumeMounts:
        - name: trust
          mountPath: /etc/trust
          readOnly: true
      volumes:
      - name: trust
        configMap:
          name: lab-ca-bundle
EOF

mkdir -p /root/answers

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Killercoda shows only pass/fail, never a verify script's output, so each
# check writes its reason to /root/.check and `why` prints it.
cat > /usr/local/bin/why <<'WRAP'
#!/bin/bash
if [ -s /root/.check ]; then
  cat /root/.check
else
  echo "No check has run yet -- press CHECK, then run 'why' again."
fi
WRAP
chmod +x /usr/local/bin/why

# An HTTPS request to the web Service from this node. With no argument it
# trusts nothing beyond the system store; with a file, it trusts that file.
cat > /usr/local/bin/webcurl <<'WRAP'
#!/bin/bash
CA=$1
IP=$(kubectl -n app get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -z "$IP" ]; then
  echo "There is no web Service in namespace app yet."
  exit 1
fi
if [ -n "$CA" ]; then
  curl -sS --cacert "$CA" --resolve "web.app.svc.cluster.local:8443:$IP" \
    https://web.app.svc.cluster.local:8443/
else
  curl -sS --resolve "web.app.svc.cluster.local:8443:$IP" \
    https://web.app.svc.cluster.local:8443/
fi
echo "curl exit code: $?"
WRAP
chmod +x /usr/local/bin/webcurl

# The leaf certificate actually being served, with no request made -- just the
# handshake and what came back in it.
cat > /usr/local/bin/servedcert <<'WRAP'
#!/bin/bash
IP=$(kubectl -n app get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -z "$IP" ]; then
  echo "There is no web Service in namespace app yet."
  exit 1
fi
echo | timeout 5 openssl s_client -connect "$IP:8443" \
  -servername web.app.svc.cluster.local 2>/dev/null \
  | openssl x509 -noout -issuer -subject -ext subjectAltName
WRAP
chmod +x /usr/local/bin/servedcert

touch /tmp/.initfinished
