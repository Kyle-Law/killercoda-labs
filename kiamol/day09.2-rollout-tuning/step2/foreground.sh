#!/bin/bash

echo "Deploying shop-v1..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

for i in $(seq 1 40); do
  READY=$(kubectl get deployment shop-v1 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "5" ] && break
  sleep 2
done

echo "Ready. Good luck!"
