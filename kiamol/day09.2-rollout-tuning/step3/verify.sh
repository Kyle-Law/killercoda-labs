#!/bin/bash

LIMIT=$(kubectl get deployment history-app -o jsonpath='{.spec.revisionHistoryLimit}' 2>/dev/null)
[ "$LIMIT" == "2" ] || exit 1

# 1 active ReplicaSet + 2 retained old ones
for i in $(seq 1 12); do
  RS_COUNT=$(kubectl get rs -l app=history-app --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$RS_COUNT" == "3" ] && exit 0
  sleep 5
done

exit 1
