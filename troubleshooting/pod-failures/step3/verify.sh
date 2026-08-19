#!/bin/bash

for i in $(seq 1 6); do
  PHASE=$(kubectl get pod oom-pod -o jsonpath='{.status.phase}' 2>/dev/null)
  READY=$(kubectl get pod oom-pod -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$PHASE" == "Running" ] && [ "$READY" == "true" ] || exit 1
  sleep 5
done

# and not sitting there mid-OOM right now
CURRENT_REASON=$(kubectl get pod oom-pod -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' 2>/dev/null)
[ "$CURRENT_REASON" != "OOMKilled" ]
