#!/bin/bash

echo "Deploying api..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get deployment api -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 2
done

echo "Ready. Good luck!"
