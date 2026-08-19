#!/bin/bash

echo "Deploying a Pod..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

# wait until it has actually been OOMKilled at least once, so the evidence
# is there regardless of scheduling/image-pull timing
for i in $(seq 1 30); do
  REASON=$(kubectl get pod oom-pod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
  [ "$REASON" == "OOMKilled" ] && break
  sleep 2
done

echo "Ready. Good luck!"
