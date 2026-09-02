#!/bin/bash

# priorities must differ in the right direction, or nothing below is meaningful
R=$(kubectl get priorityclass research -o jsonpath='{.value}' 2>/dev/null)
P=$(kubectl get priorityclass production -o jsonpath='{.value}' 2>/dev/null)
[ -n "$R" ] && [ -n "$P" ] || exit 1
[ "$P" -gt "$R" ] || exit 1

# Preemption is inherently slow - notice, evict, reschedule - and can briefly
# over-evict before settling, so poll for the SETTLED state rather than an
# exact intermediate count.
for i in $(seq 1 24); do
  INF=$(kubectl get pods -l app=inference --no-headers 2>/dev/null | grep -c "Running")
  RES_RUN=$(kubectl get pods -l app=research --no-headers 2>/dev/null | grep -c "Running")
  RES_PEND=$(kubectl get pods -l app=research --no-headers 2>/dev/null | grep -c "Pending")
  # production got all its GPUs; research was pushed out and is queued behind
  # it; and the node is fully allocated again (no GPU left idle)
  if [ "$INF" == "2" ] && [ "$RES_PEND" -ge 1 ] && [ $((INF + RES_RUN)) -eq 4 ]; then
    exit 0
  fi
  sleep 5
done

exit 1
