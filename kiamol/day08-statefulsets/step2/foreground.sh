#!/bin/bash

echo "Deploying a test client..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  READY=$(kubectl get pod dns-client -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] && break
  sleep 2
done

echo "Ready. Good luck!"
