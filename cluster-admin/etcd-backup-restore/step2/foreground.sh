#!/bin/bash

echo "Simulating a disaster..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

for i in $(seq 1 10); do
  kubectl get configmap important-data >/dev/null 2>&1 || break
  sleep 2
done

echo "Ready. Good luck!"
