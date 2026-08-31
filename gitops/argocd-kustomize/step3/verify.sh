#!/bin/bash

for i in $(seq 1 24); do
  OUT=$(argocd app get kustomize-guestbook --core 2>/dev/null)
  OLD_GONE=$(kubectl -n default get deployment kustomize-guestbook-ui --ignore-not-found -o name 2>/dev/null)
  NEW_UP=$(kubectl -n default get deployment test-guestbook-ui -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && \
     [ -z "$OLD_GONE" ] && [ "$NEW_UP" -ge 1 ] 2>/dev/null; then
    exit 0
  fi
  sleep 5
done

exit 1
