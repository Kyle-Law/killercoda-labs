#!/bin/bash

helm history podinfo3 2>/dev/null | grep -qi "rollback" || exit 1

REVS=$(helm history podinfo3 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
[ "$REVS" -ge 3 ] 2>/dev/null || exit 1

for i in $(seq 1 12); do
  IMG=$(kubectl get pods -l app.kubernetes.io/name=podinfo3 -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null)
  READY=$(kubectl get pods -l app.kubernetes.io/name=podinfo3 --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$IMG" == "ghcr.io/stefanprodan/podinfo:6.5.4" ] && [ "$READY" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
