#!/bin/bash

for i in $(seq 1 24); do
  OUT=$(argocd app get guestbook --core 2>/dev/null)
  REPLICAS=$(kubectl -n default get deployment guestbook-ui -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && [ "$REPLICAS" == "1" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
