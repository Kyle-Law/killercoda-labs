#!/bin/bash

echo "Deploying a Pod..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 15); do
  PHASE=$(kubectl get pod selector-pod -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$PHASE" == "Pending" ] && break
  sleep 2
done

echo "Ready. Good luck!"
