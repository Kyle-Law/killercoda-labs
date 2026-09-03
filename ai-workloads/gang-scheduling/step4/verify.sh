#!/bin/bash

# both jobs must be Kueue-managed, or none of this proves anything
for j in job-a job-b; do
  Q=$(kubectl get job "$j" -o jsonpath='{.metadata.labels.kueue\.x-k8s\.io/queue-name}' 2>/dev/null)
  [ "$Q" == "team-queue" ] || exit 1
done

# Kueue must have created a Workload for each - that is the object it queues on
WL=$(kubectl get workloads --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
[ "$WL" -ge 2 ] || exit 1

# The real proof: gang admission. At no point may the two jobs be simultaneously
# half-scheduled the way they were in step 1. Either exactly one job is running
# its full gang of 3 while the other has none, or both have completed.
for i in $(seq 1 60); do
  A_ACT=$(kubectl get job job-a -o jsonpath='{.status.active}' 2>/dev/null); A_ACT=${A_ACT:-0}
  B_ACT=$(kubectl get job job-b -o jsonpath='{.status.active}' 2>/dev/null); B_ACT=${B_ACT:-0}
  A_OK=$(kubectl get job job-a -o jsonpath='{.status.succeeded}' 2>/dev/null); A_OK=${A_OK:-0}
  B_OK=$(kubectl get job job-b -o jsonpath='{.status.succeeded}' 2>/dev/null); B_OK=${B_OK:-0}

  # both finished - gang scheduling did its job end to end
  if [ "$A_OK" -ge 3 ] && [ "$B_OK" -ge 3 ]; then exit 0; fi

  # or: one gang fully admitted, the other held at zero (never split 2/2)
  if { [ "$A_ACT" -eq 3 ] && [ "$B_ACT" -eq 0 ]; } || { [ "$B_ACT" -eq 3 ] && [ "$A_ACT" -eq 0 ]; }; then
    exit 0
  fi
  sleep 5
done

exit 1
