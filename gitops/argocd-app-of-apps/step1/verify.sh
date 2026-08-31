#!/bin/bash

for i in $(seq 1 30); do
  OUT=$(argocd app get app-of-apps --core 2>/dev/null)
  G_OUT=$(argocd app get example.guestbook --core 2>/dev/null)
  K_OUT=$(argocd app get example.kustomize-guestbook --core 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && \
     echo "$G_OUT" | grep -q "^Sync Status:.*Synced" && echo "$G_OUT" | grep -q "^Health Status:.*Healthy" && \
     echo "$K_OUT" | grep -q "^Sync Status:.*Synced" && echo "$K_OUT" | grep -q "^Health Status:.*Healthy"; then
    exit 0
  fi
  sleep 5
done

exit 1
