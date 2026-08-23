#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-bg
      version: blue
  template:
    metadata:
      labels:
        app: web-bg
        version: blue
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: web-bg
spec:
  selector:
    app: web-bg
    version: blue
  ports:
  - port: 80
EOF

touch /tmp/step4-applied
