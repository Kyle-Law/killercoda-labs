#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: selector-pod
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
EOF

touch /tmp/step1-applied
