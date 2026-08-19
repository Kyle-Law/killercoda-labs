#!/bin/bash

echo "Deploying a test client..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get pod dns-client -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] && break
  sleep 2
done

echo "Ready. Good luck!"
