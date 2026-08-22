#!/bin/bash

for i in $(seq 1 12); do
  SUCCEEDED=$(kubectl get job broken-job -o jsonpath='{.status.succeeded}' 2>/dev/null)
  if [ -n "$SUCCEEDED" ] && [ "$SUCCEEDED" -ge 1 ] 2>/dev/null; then
    exit 0
  fi
  sleep 5
done

exit 1
