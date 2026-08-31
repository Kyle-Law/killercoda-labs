#!/bin/bash

for i in $(seq 1 24); do
  OUT=$(argocd app get podinfo-helm --core 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy"; then
    LABEL=$(kubectl -n default get deployment podinfo-helm -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)
    HELM_STATUS=$(helm status podinfo-helm 2>&1)
    if [ "$LABEL" == "Helm" ] && echo "$HELM_STATUS" | grep -qi "not found"; then
      exit 0
    fi
  fi
  sleep 5
done

exit 1
