#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: risky-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: node-root
      mountPath: /host
  volumes:
  - name: node-root
    hostPath:
      path: /
      type: Directory
EOF

touch /tmp/step3-applied
