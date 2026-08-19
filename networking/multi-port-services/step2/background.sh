#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multi-api
  template:
    metadata:
      labels:
        app: multi-api
    spec:
      containers:
      - name: app
        image: nginx:stable-alpine
        ports:
        - name: http
          containerPort: 80
        - name: metrics
          containerPort: 9113
EOF

touch /tmp/step2-applied
