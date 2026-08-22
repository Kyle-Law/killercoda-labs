#!/bin/bash

DEADLINE=$(kubectl get job capped-job -o jsonpath='{.spec.activeDeadlineSeconds}' 2>/dev/null)
[ "$DEADLINE" == "10" ] || exit 1

for i in $(seq 1 12); do
  REASON=$(kubectl get job capped-job -o jsonpath="{.status.conditions[?(@.type=='Failed')].reason}" 2>/dev/null)
  [ "$REASON" == "DeadlineExceeded" ] && exit 0
  sleep 5
done

exit 1
