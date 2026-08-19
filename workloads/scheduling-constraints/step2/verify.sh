#!/bin/bash

for i in $(seq 1 3); do
  PHASE=$(kubectl get pod taint-pod -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$PHASE" == "Running" ] || exit 1
  sleep 5
done

exit 0
