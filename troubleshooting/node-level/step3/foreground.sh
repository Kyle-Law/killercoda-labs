#!/bin/bash

echo "Breaking the kubelet's connection to the API server..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
for i in $(seq 1 30); do
  STATUS=$(kubectl get node "$NODE" -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}" 2>/dev/null)
  [ "$STATUS" != "True" ] && break
  sleep 3
done

echo "Ready. Good luck!"
