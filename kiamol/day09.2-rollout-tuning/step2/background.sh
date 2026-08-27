#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-v1
spec:
  replicas: 5
  selector:
    matchLabels:
      app: shop
      version: v1
  template:
    metadata:
      labels:
        app: shop
        version: v1
    spec:
      containers:
      - name: shop
        image: nginx:1.25-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: shop
spec:
  selector:
    app: shop
  ports:
  - port: 80
EOF

touch /tmp/step2-applied
