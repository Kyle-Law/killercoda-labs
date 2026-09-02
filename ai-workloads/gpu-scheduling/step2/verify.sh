#!/bin/bash

# exactly the node's worth of GPU pods should be running, with the surplus stuck
for i in $(seq 1 18); do
  RUNNING=$(kubectl get pods -l app=trainer --no-headers 2>/dev/null | grep -c "Running")
  PENDING=$(kubectl get pods -l app=trainer --no-headers 2>/dev/null | grep -c "Pending")
  [ "$RUNNING" == "4" ] && [ "$PENDING" -ge 1 ] && break
  sleep 5
done
[ "$RUNNING" == "4" ] || exit 1
[ "$PENDING" -ge 1 ] || exit 1

# and the captured reason must be the accelerator one specifically, not some
# other scheduling failure like a taint or a missing node selector
grep -q "Insufficient nvidia.com/gpu" /root/pending-reason 2>/dev/null || exit 1

exit 0
