#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: oom-pod
spec:
  containers:
  - name: app
    image: polinux/stress
    resources:
      requests:
        memory: "20Mi"
      limits:
        memory: "50Mi"
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "150M", "--vm-hang", "1"]
EOF

touch /tmp/step3-applied
