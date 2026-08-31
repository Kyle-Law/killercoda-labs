#!/bin/bash

for i in $(seq 1 30); do
  STATUS=$(kubectl -n default get rollout rollouts-bluegreen -o jsonpath='{.status.phase}' 2>/dev/null)
  IMAGE=$(kubectl -n default get rollout rollouts-bluegreen -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ACTIVE_POD=$(kubectl -n default get endpoints rollouts-bluegreen-active -o jsonpath='{.subsets[0].addresses[0].targetRef.name}' 2>/dev/null)
  ACTIVE_IMG=$(kubectl -n default get pod "$ACTIVE_POD" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  if [ "$STATUS" == "Healthy" ] && [ "$IMAGE" == "argoproj/rollouts-demo:yellow" ] && [ "$ACTIVE_IMG" == "argoproj/rollouts-demo:yellow" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
