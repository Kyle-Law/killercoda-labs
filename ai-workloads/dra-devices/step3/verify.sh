#!/bin/bash

# the satisfiable CEL request must have scheduled
for i in $(seq 1 24); do
  PHASE=$(kubectl get pod pod-big -n dra-demo -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$PHASE" == "Running" ] && break
  sleep 5
done
[ "$PHASE" == "Running" ] || exit 1

# and its selectors must actually be CEL, not a plain deviceClassName request -
# otherwise nothing about attribute selection was demonstrated
kubectl get resourceclaimtemplate big-gpu -n dra-demo -o yaml 2>/dev/null | grep -q "cel:" || exit 1

# the unsatisfiable one must be Pending with an UNALLOCATED claim - proving it
# failed on the expression, not on capacity
PEND=$(kubectl get pod pod-huge -n dra-demo -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$PEND" == "Pending" ] || exit 1

HUGE_ALLOC=$(kubectl get resourceclaim -n dra-demo \
  -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.status.allocation.devices.results[0].device}{"\n"}{end}' 2>/dev/null \
  | grep "^pod-huge" | grep -c "=." )
[ "${HUGE_ALLOC:-0}" == "0" ] || exit 1

exit 0
