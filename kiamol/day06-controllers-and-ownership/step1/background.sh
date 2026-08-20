#!/bin/bash

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: whoami-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: whoami-web
  template:
    metadata:
      labels:
        app: whoami-web
    spec:
      containers:
      - name: whoami
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
EOF

touch /tmp/step1-applied
