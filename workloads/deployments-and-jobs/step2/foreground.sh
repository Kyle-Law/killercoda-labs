#!/bin/bash

echo "Starting a bad rollout..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

# wait until the rollout is visibly stuck - at least one unavailable replica
for i in $(seq 1 20); do
  UNAVAIL=$(kubectl get deployment frontend -o jsonpath='{.status.unavailableReplicas}' 2>/dev/null)
  [ -n "$UNAVAIL" ] && [ "$UNAVAIL" != "0" ] && break
  sleep 3
done

echo "Ready. Good luck!"
