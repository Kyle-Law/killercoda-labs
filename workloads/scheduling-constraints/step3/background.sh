#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spread-app
  template:
    metadata:
      labels:
        app: spread-app
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: spread-app
            topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: nginx:stable-alpine
EOF

touch /tmp/step3-applied
