#!/bin/bash

helm status podinfo 2>/dev/null | grep -q "^STATUS: deployed" || exit 1

for i in $(seq 1 12); do
  TOTAL=$(kubectl get pods -l app.kubernetes.io/name=podinfo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  BROKEN=$(kubectl get pods -l app.kubernetes.io/name=podinfo --no-headers 2>/dev/null | grep -vc "1/1.*Running")
  [ "$TOTAL" -ge 1 ] 2>/dev/null && [ "$BROKEN" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
