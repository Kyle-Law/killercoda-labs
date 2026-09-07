#!/bin/bash

mkdir -p /root/app/base /root/app/overlay

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
          env:
            - name: KEEP_ME
              value: "important"
            - name: LOG_LEVEL
              value: "info"
          ports:
            - containerPort: 80
        - name: logger
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo tick; sleep 30; done"]
YAML

cat > /root/app/base/kustomization.yaml <<'YAML'
resources:
  - deploy.yaml
YAML

cat > /root/app/overlay/kustomization.yaml <<'YAML'
resources:
  - ../base
YAML

for img in nginx:1.27-alpine busybox:1.36; do
  ctr -n k8s.io images pull "docker.io/library/$img" >/dev/null 2>&1 || crictl pull "$img" >/dev/null 2>&1 || true
done

touch /tmp/.initfinished
