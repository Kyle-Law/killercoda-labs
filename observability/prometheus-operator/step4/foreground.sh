#!/bin/bash

echo "Deploying sample-app across both nodes..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done

for i in $(seq 1 40); do
  READY=$(kubectl get deployment sample-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 5
done

echo "Ready. Good luck!"
