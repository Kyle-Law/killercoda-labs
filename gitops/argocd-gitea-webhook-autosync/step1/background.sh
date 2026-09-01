#!/bin/bash

ARGOCD_VERSION=v3.5.2
GITEA_VERSION=1.27.3

# --- Argo CD (full install, UI included, plain HTTP) ---
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n argocd wait --for=condition=available --timeout=240s deployment --all
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=240s

kubectl -n argocd patch configmap argocd-cmd-params-cm -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deployment/argocd-server
kubectl -n argocd rollout status deployment/argocd-server --timeout=180s

kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30080,"protocol":"TCP"},{"name":"https","port":443,"targetPort":8080,"protocol":"TCP"}]}}'

for i in $(seq 1 30); do
  kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > /root/argocd-admin-password.txt
echo >> /root/argocd-admin-password.txt

# --- Gitea (SQLite, no setup wizard) ---
# ROOT_URL is set to Gitea's own in-cluster Service DNS name, not the NodePort
# address a browser uses -- that's what makes a push-triggered webhook payload
# describe the repo the same way this lab's Argo CD Application does, so the
# two can be matched up. security.ALLOWED_HOST_LIST is what lets Gitea call an
# in-cluster address at all -- by default it refuses to, as basic SSRF
# protection against a webhook pointed at internal infrastructure.
kubectl create namespace gitea
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  namespace: gitea
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitea
  template:
    metadata:
      labels:
        app: gitea
    spec:
      containers:
      - name: gitea
        image: gitea/gitea:${GITEA_VERSION}
        env:
        - name: GITEA__security__INSTALL_LOCK
          value: "true"
        - name: GITEA__database__DB_TYPE
          value: "sqlite3"
        - name: GITEA__server__ROOT_URL
          value: "http://gitea.gitea.svc.cluster.local:3000/"
        - name: GITEA__server__HTTP_PORT
          value: "3000"
        - name: GITEA__security__ALLOWED_HOST_LIST
          value: "private,loopback"
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 22
          name: ssh
        readinessProbe:
          httpGet:
            path: /api/healthz
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: gitea
  namespace: gitea
spec:
  type: NodePort
  selector:
    app: gitea
  ports:
  - name: http
    port: 3000
    targetPort: 3000
    nodePort: 30300
  - name: ssh
    port: 22
    targetPort: 22
EOF
kubectl -n gitea rollout status deployment/gitea --timeout=180s

GITEA_POD=$(kubectl -n gitea get pod -l app=gitea -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitea exec "$GITEA_POD" -- su git -c \
  "gitea admin user create --username admin --password 'AdminPass123!' --email admin@example.com --admin" \
  2>/dev/null || true
echo "admin / AdminPass123!" > /root/gitea-admin-credentials.txt

mkdir -p /root/solar-system-app
cat > /root/solar-system-app/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: solar-system
  labels:
    app: solar-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: solar-system
  template:
    metadata:
      labels:
        app: solar-system
    spec:
      containers:
      - name: solar-system
        image: handafew/solar-system:v3
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
EOF
cat > /root/solar-system-app/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: solar-system
  labels:
    app: solar-system
spec:
  type: NodePort
  selector:
    app: solar-system
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
EOF

touch /tmp/step1-applied
