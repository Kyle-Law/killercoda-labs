#!/bin/bash

echo "Deploying a Service..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  EP=$(kubectl get endpoints backend-svc -o jsonpath='{.subsets}' 2>/dev/null)
  [ -z "$EP" ] && break
  sleep 2
done

echo "Ready. Good luck!"
