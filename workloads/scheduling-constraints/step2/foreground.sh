#!/bin/bash

echo "Tainting the node and deploying a Pod..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

for i in $(seq 1 15); do
  PHASE=$(kubectl get pod taint-pod -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$PHASE" == "Pending" ] && break
  sleep 2
done

echo "Ready. Good luck!"
