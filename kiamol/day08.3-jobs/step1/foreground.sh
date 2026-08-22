#!/bin/bash

echo "Deploying broken-job..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  FAILED_COND=$(kubectl get job broken-job -o jsonpath="{.status.conditions[?(@.type=='Failed')].status}" 2>/dev/null)
  [ "$FAILED_COND" == "True" ] && break
  sleep 3
done

echo "Ready. Good luck!"
