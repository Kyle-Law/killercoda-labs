#!/bin/bash

for i in $(seq 1 6); do
  READY=$(kubectl get deployment spread-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] || exit 1
  sleep 5
done

exit 0
