#!/bin/bash

echo "Deploying web-blue..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get deployment web-blue -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 2
done

echo "Ready. Good luck!"
