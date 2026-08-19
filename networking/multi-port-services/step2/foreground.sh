#!/bin/bash

echo "Deploying multi-api..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get deployment multi-api -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "1" ] && break
  sleep 2
done

echo "Ready. Good luck!"
