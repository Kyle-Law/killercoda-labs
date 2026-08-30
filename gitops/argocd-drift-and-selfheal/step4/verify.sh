#!/bin/bash

for i in $(seq 1 24); do
  OUT=$(argocd app get guestbook --core 2>/dev/null)
  SVC=$(kubectl -n default get svc guestbook-ui -o name 2>/dev/null)
  if [ -n "$SVC" ] && echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy"; then
    exit 0
  fi
  sleep 5
done

exit 1
