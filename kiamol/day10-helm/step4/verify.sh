#!/bin/bash

READY_COUNT=0
for i in $(seq 1 12); do
  READY_COUNT=$(kubectl get pods -l app.kubernetes.io/name=webapp --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$READY_COUNT" -ge 1 ] 2>/dev/null && break
  sleep 5
done
[ "$READY_COUNT" -ge 1 ] 2>/dev/null || exit 1

helm list --filter '^webapp$' 2>/dev/null | grep -q "webapp-0.1.0" || exit 1

IMG=$(kubectl get pods -l app.kubernetes.io/name=webapp -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null)
echo "$IMG" | grep -q "stable-alpine"
