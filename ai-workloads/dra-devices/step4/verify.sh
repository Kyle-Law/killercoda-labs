#!/bin/bash

# both Pods running off one shared claim
for i in $(seq 1 24); do
  P0=$(kubectl get pod share0 -n dra-demo -o jsonpath='{.status.phase}' 2>/dev/null)
  P1=$(kubectl get pod share1 -n dra-demo -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$P0" == "Running" ] && [ "$P1" == "Running" ] && break
  sleep 5
done
[ "$P0" == "Running" ] && [ "$P1" == "Running" ] || exit 1

# the claim must record BOTH Pods as reserving it - that is what proves sharing
# rather than two Pods happening to each get their own device
RESERVED=$(kubectl get resourceclaim shared-gpu -n dra-demo \
  -o jsonpath='{.status.reservedFor[*].name}' 2>/dev/null)
echo "$RESERVED" | grep -q "share0" || exit 1
echo "$RESERVED" | grep -q "share1" || exit 1

# and both containers must have been given the same device
D0=$(kubectl logs share0 -n dra-demo 2>/dev/null | grep -o "GPU_DEVICE[^=]*=[^ ]*" | sort | tr -d '[:space:]')
D1=$(kubectl logs share1 -n dra-demo 2>/dev/null | grep -o "GPU_DEVICE[^=]*=[^ ]*" | sort | tr -d '[:space:]')
[ -n "$D0" ] || exit 1
[ "$D0" == "$D1" ] || exit 1

exit 0
