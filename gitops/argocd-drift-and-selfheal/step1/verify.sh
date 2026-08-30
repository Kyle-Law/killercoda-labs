#!/bin/bash

for i in $(seq 1 24); do
  OUT=$(argocd app get guestbook --core 2>/dev/null)
  echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && exit 0
  sleep 5
done

exit 1
