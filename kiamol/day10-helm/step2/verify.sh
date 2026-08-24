#!/bin/bash

READY_COUNT=0
for i in $(seq 1 12); do
  READY_COUNT=$(kubectl get pods -l app.kubernetes.io/name=podinfo --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$READY_COUNT" -ge 2 ] 2>/dev/null && break
  sleep 5
done
[ "$READY_COUNT" -ge 2 ] 2>/dev/null || exit 1

helm list --filter '^podinfo$' 2>/dev/null | grep -q "podinfo-6.5.4" || exit 1

VALUES=$(helm get values podinfo 2>/dev/null)
echo "$VALUES" | grep -qE '^replicaCount:[[:space:]]*2[[:space:]]*$'
