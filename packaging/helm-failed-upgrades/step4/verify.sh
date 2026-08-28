#!/bin/bash

helm status podinfo4 2>/dev/null | grep -q "^STATUS: deployed" || exit 1

REVS=$(helm history podinfo4 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
[ "$REVS" -ge 3 ] 2>/dev/null || exit 1

for i in $(seq 1 12); do
  REPLICAS=$(kubectl get deployment podinfo4 -o jsonpath='{.spec.replicas}' 2>/dev/null)
  READY=$(kubectl get pods -l app.kubernetes.io/name=podinfo4 --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$REPLICAS" == "1" ] && [ "$READY" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
