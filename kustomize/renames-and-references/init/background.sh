#!/bin/bash

mkdir -p /root/app/base

cat > /root/app/base/backend.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
YAML

# The frontend reads the backend's address from a ConfigMap and curls it in a
# loop, so a broken reference shows up as a runtime failure rather than a
# manifest error.
cat > /root/app/base/frontend.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: appcfg
data:
  BACKEND_HOST: "backend"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: busybox:1.36
          envFrom:
            - configMapRef:
                name: appcfg
          command:
            - sh
            - -c
            - |
              while true; do
                if wget -q -T 3 -O /dev/null "http://${BACKEND_HOST}"; then
                  echo "OK reached ${BACKEND_HOST}"
                else
                  echo "FAIL cannot reach ${BACKEND_HOST}"
                fi
                sleep 5
              done
YAML

cat > /root/app/base/kustomization.yaml <<'YAML'
resources:
  - backend.yaml
  - frontend.yaml
YAML

for img in nginx:1.27-alpine busybox:1.36; do
  ctr -n k8s.io images pull "docker.io/library/$img" >/dev/null 2>&1 || crictl pull "$img" >/dev/null 2>&1 || true
done

touch /tmp/.initfinished
