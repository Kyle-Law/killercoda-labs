#!/bin/bash

echo "Stopping the kubelet..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

# the API server needs a grace period (default ~40s) before it marks
# the node NotReady after heartbeats stop
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
for i in $(seq 1 30); do
  STATUS=$(kubectl get node "$NODE" -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}" 2>/dev/null)
  [ "$STATUS" != "True" ] && break
  sleep 3
done

echo "Ready. Good luck!"
