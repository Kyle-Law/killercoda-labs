#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pull-pod
spec:
  containers:
  - name: app
    image: busyboxx:latest
    command: ["sh", "-c", "sleep 3600"]
EOF

touch /tmp/step2-ready
