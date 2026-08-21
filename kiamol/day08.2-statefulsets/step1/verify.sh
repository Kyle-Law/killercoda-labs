#!/bin/bash

for i in $(seq 1 3); do
  READY=$(kubectl get statefulset db -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "3" ] || exit 1
  sleep 5
done

exit 0
