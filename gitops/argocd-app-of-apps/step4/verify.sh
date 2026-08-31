#!/bin/bash

for i in $(seq 1 30); do
  A_OUT=$(argocd app get lightweight-app-a --core 2>/dev/null)
  B_GONE=$(kubectl get application lightweight-app-b -n argocd --ignore-not-found -o name 2>/dev/null)
  if echo "$A_OUT" | grep -q "^Sync Status:.*Synced" && echo "$A_OUT" | grep -q "^Health Status:.*Healthy" && [ -z "$B_GONE" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
