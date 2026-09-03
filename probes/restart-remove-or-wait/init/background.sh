#!/bin/bash

# Pre-pull podinfo so the first step isn't waiting on a registry pull while
# it's also trying to demonstrate probe timing.
ctr -n k8s.io images pull ghcr.io/stefanprodan/podinfo:6.5.4 >/dev/null 2>&1 \
  || crictl pull ghcr.io/stefanprodan/podinfo:6.5.4 >/dev/null 2>&1 \
  || true

# The broken workload step 1 diagnoses. The app needs 60s before it serves
# anything; the liveness probe gives up after ~11s. It can never win.
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-starter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: slow-starter
  template:
    metadata:
      labels:
        app: slow-starter
    spec:
      containers:
      - name: app
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        command: ["/bin/sh","-c","sleep 60 && ./podinfo"]
        ports:
        - containerPort: 9898
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 9898
          initialDelaySeconds: 5
          periodSeconds: 3
          failureThreshold: 2
EOF

touch /tmp/.initfinished
