#!/bin/bash

# podinfo exposes real Prometheus metrics on /metrics, and spreading it across
# both nodes makes target discovery actually meaningful
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: sample-app
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        ports:
        - name: http
          containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  labels:
    app: sample-app
spec:
  selector:
    app: sample-app
  ports:
  - name: http
    port: 9898
    targetPort: http
EOF

touch /tmp/step4-applied
