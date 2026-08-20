#!/bin/bash

echo "Deploying a bare ReplicaSet..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  READY=$(kubectl get rs whoami-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "1" ] && break
  sleep 2
done

echo "Ready. Good luck!"
