#!/bin/bash

ARGOCD_VERSION=v3.5.2
GITEA_VERSION=1.27.3

# --- Argo CD (full install, UI included) ---
if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
  kubectl create namespace argocd
  kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
  kubectl -n argocd wait --for=condition=available --timeout=240s deployment --all
  kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=240s

  # Serve plain HTTP -- a self-signed cert behind a NodePort just adds a
  # browser warning with nothing protecting anything behind it anyway.
  kubectl -n argocd patch configmap argocd-cmd-params-cm -p '{"data":{"server.insecure":"true"}}'
  kubectl -n argocd rollout restart deployment/argocd-server
  kubectl -n argocd rollout status deployment/argocd-server --timeout=180s
fi

for i in $(seq 1 30); do
  kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > /root/argocd-admin-password.txt
echo >> /root/argocd-admin-password.txt

# --- Gitea (SQLite, no setup wizard) ---
if ! kubectl get deployment gitea -n gitea >/dev/null 2>&1; then
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
          value: "http://localhost:30300/"
        - name: GITEA__server__HTTP_PORT
          value: "3000"
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
  selector:
    app: gitea
  ports:
  - name: http
    port: 3000
    targetPort: 3000
  - name: ssh
    port: 22
    targetPort: 22
EOF
  kubectl -n gitea rollout status deployment/gitea --timeout=180s
fi

GITEA_POD=$(kubectl -n gitea get pod -l app=gitea -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitea exec "$GITEA_POD" -- su git -c \
  "gitea admin user create --username admin --password 'AdminPass123!' --email admin@example.com --admin" \
  2>/dev/null || true
echo "admin / AdminPass123!" > /root/gitea-admin-credentials.txt

touch /tmp/step1-applied
