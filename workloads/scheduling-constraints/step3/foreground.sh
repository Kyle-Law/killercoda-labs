#!/bin/bash

echo "Deploying spread-app..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  READY=$(kubectl get deployment spread-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "1" ] && break
  sleep 3
done

echo "Ready. Good luck!"
