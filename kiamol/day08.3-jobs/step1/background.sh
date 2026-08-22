#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: broken-job
spec:
  backoffLimit: 1
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "exit 1"]
      restartPolicy: Never
EOF

touch /tmp/step1-applied
