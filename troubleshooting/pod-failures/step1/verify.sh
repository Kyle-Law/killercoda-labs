#!/bin/bash

# require the fix to hold across several checks, not just a lucky instant
for i in $(seq 1 3); do
  PHASE=$(kubectl get pod crash-pod -o jsonpath='{.status.phase}' 2>/dev/null)
  READY=$(kubectl get pod crash-pod -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$PHASE" == "Running" ] && [ "$READY" == "true" ] || exit 1
  sleep 5
done

exit 0
