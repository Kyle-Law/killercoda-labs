#!/bin/bash

# the deadlock is a stable state, so it is genuinely checkable: every GPU
# allocated, both jobs short of their gang size, nothing progressing
for i in $(seq 1 18); do
  A=$(kubectl get pods -l app=job-a --no-headers 2>/dev/null | grep -c "Running")
  B=$(kubectl get pods -l app=job-b --no-headers 2>/dev/null | grep -c "Running")
  PEND=$(kubectl get pods -l role=training --no-headers 2>/dev/null | grep -c "Pending")
  TOTAL=$((A + B))
  # all 4 GPUs consumed, neither job reached its 3-worker gang, and the
  # remainder is stuck waiting
  if [ "$TOTAL" == "4" ] && [ "$A" -lt 3 ] && [ "$B" -lt 3 ] && [ "$PEND" -ge 1 ]; then
    exit 0
  fi
  sleep 5
done

exit 1
