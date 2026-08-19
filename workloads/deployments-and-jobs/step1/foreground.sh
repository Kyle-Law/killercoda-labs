#!/bin/bash

echo "Deploying frontend..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "3" ] && break
  sleep 2
done

echo "Ready. Good luck!"
