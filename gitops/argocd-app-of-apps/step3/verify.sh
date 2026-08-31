#!/bin/bash

for i in $(seq 1 30); do
  ALL_OK=1
  for env in dev staging prod; do
    OUT=$(argocd app get "guestbook-$env" --core 2>/dev/null)
    echo "$OUT" | grep -q "^Sync Status:.*Synced" || ALL_OK=0
    echo "$OUT" | grep -q "^Health Status:.*Healthy" || ALL_OK=0
  done
  [ "$ALL_OK" -eq 1 ] && exit 0
  sleep 5
done

exit 1
