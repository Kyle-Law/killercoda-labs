#!/bin/bash

echo "Scaling db to 3 replicas..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get statefulset db -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "3" ] && break
  sleep 2
done

echo "Ready. Good luck!"
