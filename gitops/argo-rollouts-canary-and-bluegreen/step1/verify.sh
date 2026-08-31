#!/bin/bash

for i in $(seq 1 30); do
  STATUS=$(kubectl -n default get rollout rollouts-demo -o jsonpath='{.status.phase}' 2>/dev/null)
  READY=$(kubectl -n default get rollout rollouts-demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$STATUS" == "Healthy" ] && [ "$READY" == "5" ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
