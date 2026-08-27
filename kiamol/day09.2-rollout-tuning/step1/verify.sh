#!/bin/bash

DEADLINE=$(kubectl get deployment payments -o jsonpath='{.spec.progressDeadlineSeconds}' 2>/dev/null)
[ "$DEADLINE" == "30" ] || exit 1

for i in $(seq 1 16); do
  REASON=$(kubectl get deployment payments -o jsonpath="{.status.conditions[?(@.type=='Progressing')].reason}" 2>/dev/null)
  [ "$REASON" == "ProgressDeadlineExceeded" ] && exit 0
  sleep 5
done

exit 1
