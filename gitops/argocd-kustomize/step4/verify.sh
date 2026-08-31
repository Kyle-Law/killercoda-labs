#!/bin/bash

for i in $(seq 1 24); do
  OUT=$(argocd app get kustomize-guestbook --core 2>/dev/null)
  LABEL=$(kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.metadata.labels.environment}' 2>/dev/null)
  SELECTOR=$(kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.spec.selector.matchLabels.environment}' 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && \
     [ "$LABEL" == "production" ] && [ -z "$SELECTOR" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
