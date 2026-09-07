#!/bin/bash

mkdir -p /root/app/base /root/app/overlays/staging /root/app/overlays/prod

cat > /root/app/base/deploy.yaml <<'YAML'
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
        - name: app
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
YAML

cat > /root/app/base/kustomization.yaml <<'YAML'
resources:
  - deploy.yaml
YAML

# The same monitoring patch, copied into both overlays. This duplication is
# the starting condition the scenario is about.
for env in staging prod; do
cat > /root/app/overlays/$env/monitoring-patch.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
YAML
cat > /root/app/overlays/$env/kustomization.yaml <<YAML
namePrefix: $env-
resources:
  - ../../base
patches:
  - path: monitoring-patch.yaml
YAML
done

ctr -n k8s.io images pull docker.io/library/nginx:1.27-alpine >/dev/null 2>&1 \
  || crictl pull nginx:1.27-alpine >/dev/null 2>&1 || true

touch /tmp/.initfinished
