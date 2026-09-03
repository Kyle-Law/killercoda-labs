#!/bin/bash

# The deadlock is a stable state, so it is genuinely observable: all four GPUs
# consumed, neither job at its gang size of 3, remainder stuck Pending.
# Accept EITHER the deadlock still standing, or the cleanup already done -
# the step ends by deleting both, so a learner who followed through must pass.
SEEN=0
for i in $(seq 1 18); do
  A=$(kubectl get pods -l app=job-a --no-headers 2>/dev/null | grep -c "Running")
  B=$(kubectl get pods -l app=job-b --no-headers 2>/dev/null | grep -c "Running")
  PEND=$(kubectl get pods -l role=training --no-headers 2>/dev/null | grep -c "Pending")
  if [ $((A + B)) -eq 4 ] && [ "$A" -lt 3 ] && [ "$B" -lt 3 ] && [ "$PEND" -ge 1 ]; then
    SEEN=1; break
  fi
  # cleanup done - both deployments gone
  if ! kubectl get deployment job-a >/dev/null 2>&1 && ! kubectl get deployment job-b >/dev/null 2>&1; then
    SEEN=1; break
  fi
  sleep 5
done

[ "$SEEN" == "1" ] || exit 1
exit 0
