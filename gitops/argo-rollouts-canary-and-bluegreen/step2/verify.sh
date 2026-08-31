#!/bin/bash

for i in $(seq 1 30); do
  STATUS=$(kubectl -n default get rollout rollouts-demo -o jsonpath='{.status.phase}' 2>/dev/null)
  IMAGE=$(kubectl -n default get rollout rollouts-demo -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  READY=$(kubectl -n default get rollout rollouts-demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ "$STATUS" == "Healthy" ] && [ "$IMAGE" == "argoproj/rollouts-demo:yellow" ] && [ "$READY" == "5" ] 2>/dev/null; then
    exit 0
  fi
  sleep 5
done

exit 1
