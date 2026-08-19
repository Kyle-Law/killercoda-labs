#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: probe-pod
spec:
  containers:
  - name: nginx
    image: nginx:stable-alpine
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /healthz
        port: 80
      periodSeconds: 5
EOF

touch /tmp/step4-ready
