#!/bin/bash

for i in $(seq 1 30); do
  STATUS=$(kubectl -n default get rollout rollouts-demo -o jsonpath='{.status.phase}' 2>/dev/null)
  RUNNING=$(kubectl -n default get pods -l app=rollouts-demo -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' 2>/dev/null | sort -u)
  if [ "$STATUS" == "Degraded" ] && [ "$RUNNING" == "argoproj/rollouts-demo:blue" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
