#!/bin/bash

REVISION_COUNT=$(helm history podinfo 2>/dev/null | tail -n +2 | wc -l)
[ "$REVISION_COUNT" == "4" ] || exit 1

LAST_DESC=$(helm history podinfo 2>/dev/null | tail -1)
echo "$LAST_DESC" | grep -qi "rollback" || exit 1

READY_COUNT=0
for i in $(seq 1 12); do
  READY_COUNT=$(kubectl get pods -l app.kubernetes.io/name=podinfo --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$READY_COUNT" == "1" ] && break
  sleep 5
done
[ "$READY_COUNT" == "1" ] || exit 1

VALUES=$(helm get values podinfo 2>/dev/null)
if echo "$VALUES" | grep -qE '^replicaCount:[[:space:]]*2[[:space:]]*$'; then exit 1; fi
if echo "$VALUES" | grep -qiE '^logLevel:[[:space:]]*debug[[:space:]]*$'; then exit 1; fi

exit 0
