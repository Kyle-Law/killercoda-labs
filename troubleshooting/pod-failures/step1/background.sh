#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crash-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo crashing now; exit 1"]
EOF

touch /tmp/step1-ready
