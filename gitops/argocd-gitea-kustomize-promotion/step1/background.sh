#!/bin/bash

ARGOCD_VERSION=v3.5.2
GITEA_VERSION=1.27.3

# --- Argo CD ---
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n argocd wait --for=condition=available --timeout=300s deployment --all
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

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

# --- Gitea ---
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
EOF
kubectl -n gitea rollout status deployment/gitea --timeout=240s

GITEA_POD=$(kubectl -n gitea get pod -l app=gitea -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitea exec "$GITEA_POD" -- su git -c \
  "gitea admin user create --username admin --password 'AdminPass123!' --email admin@example.com --admin" \
  2>/dev/null || true
echo "admin / AdminPass123!" > /root/gitea-admin-credentials.txt

# --- the kustomize repo the learner will push ---
mkdir -p /root/solar-kustomize/base /root/solar-kustomize/overlays/staging /root/solar-kustomize/overlays/prod

cat > /root/solar-kustomize/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: solar-system
spec:
  replicas: 1
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
          image: handafew/solar-system:v1
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
EOF

cat > /root/solar-kustomize/base/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: solar-system
spec:
  selector:
    app: solar-system
  ports:
    - port: 80
      targetPort: 80
EOF

cat > /root/solar-kustomize/base/kustomization.yaml <<'EOF'
resources:
  - deployment.yaml
  - service.yaml
EOF

cat > /root/solar-kustomize/overlays/staging/kustomization.yaml <<'EOF'
namespace: staging
resources:
  - ../../base
images:
  - name: handafew/solar-system
    newTag: v1
EOF

cat > /root/solar-kustomize/overlays/prod/kustomization.yaml <<'EOF'
namespace: prod
resources:
  - ../../base
replicas:
  - name: solar-system
    count: 2
images:
  - name: handafew/solar-system
    newTag: v1
EOF

touch /tmp/step1-applied
