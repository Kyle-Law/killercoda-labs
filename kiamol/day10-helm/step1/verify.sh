#!/bin/bash

helm list --filter '^podinfo$' 2>/dev/null | grep -q "podinfo-6.5.4" || exit 1

for i in $(seq 1 12); do
  READY_COUNT=$(kubectl get pods -l app.kubernetes.io/name=podinfo --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$READY_COUNT" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
