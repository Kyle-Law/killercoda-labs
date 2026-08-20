#!/bin/bash

echo "Deploying legacy-app..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  READY=$(kubectl get pod legacy-app -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] && break
  sleep 2
done

echo "Ready. Good luck!"
