#!/bin/bash

echo "Deploying payments..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get deployment payments -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 2
done

echo "Ready. Good luck!"
