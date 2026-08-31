#!/bin/bash

for i in $(seq 1 30); do
  OUT=$(argocd app get pre-post-sync --core 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy"; then
    BEFORE=$(kubectl -n default get job pre-post-sync-before --ignore-not-found -o name 2>/dev/null)
    AFTER=$(kubectl -n default get job pre-post-sync-after --ignore-not-found -o name 2>/dev/null)
    if [ -z "$BEFORE" ] && [ -z "$AFTER" ]; then
      exit 0
    fi
  fi
  sleep 5
done

exit 1
