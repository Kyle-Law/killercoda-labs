#!/bin/bash

echo "Deploying a Deployment..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  PENDING=$(kubectl get pods -l app=stuck-app --no-headers 2>/dev/null | grep -c Pending)
  [ "$PENDING" -ge 1 ] && break
  sleep 2
done

echo "Ready. Good luck!"
