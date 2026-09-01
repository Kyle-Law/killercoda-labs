#!/bin/bash

for i in $(seq 1 30); do
  if ! kubectl -n solar-system get configmap solar-system-extra >/dev/null 2>&1; then
    SYNC=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
    HEALTH=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
    if [ "$SYNC" == "Synced" ] && [ "$HEALTH" == "Healthy" ]; then
      exit 0
    fi
  fi
  sleep 5
done

exit 1
