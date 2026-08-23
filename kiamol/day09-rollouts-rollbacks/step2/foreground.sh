#!/bin/bash

echo "Deploying stateful-cache and always-on..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  R1=$(kubectl get deployment stateful-cache -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  R2=$(kubectl get deployment always-on -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$R1" == "2" ] && [ "$R2" == "4" ] && break
  sleep 2
done

echo "Ready. Good luck!"
