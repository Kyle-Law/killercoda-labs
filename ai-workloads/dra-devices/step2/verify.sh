#!/bin/bash

# the Pod must be running with its claim satisfied
for i in $(seq 1 24); do
  PHASE=$(kubectl get pod pod0 -n dra-demo -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$PHASE" == "Running" ] && break
  sleep 5
done
[ "$PHASE" == "Running" ] || exit 1

# a claim must exist and be ALLOCATED to a concrete device - a Pod could
# otherwise be running without DRA having actually bound anything
for i in $(seq 1 12); do
  DEV=$(kubectl get resourceclaim -n dra-demo \
    -o jsonpath='{.items[0].status.allocation.devices.results[0].device}' 2>/dev/null)
  [ -n "$DEV" ] && break
  sleep 5
done
[ -n "$DEV" ] || exit 1

# and the driver must have injected it into the container
kubectl logs pod0 -n dra-demo 2>/dev/null | grep -q "GPU_DEVICE" || exit 1

exit 0
