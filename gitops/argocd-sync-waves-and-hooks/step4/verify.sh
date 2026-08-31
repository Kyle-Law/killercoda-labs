#!/bin/bash

for i in $(seq 1 24); do
  FRONTEND=$(kubectl -n default get replicaset frontend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  PRESYNC_COUNT=$(kubectl -n default get job -o name 2>/dev/null | grep -c upgrade-sql-schema)
  if [ "$FRONTEND" == "1" ] && [ "$PRESYNC_COUNT" -ge 2 ] 2>/dev/null; then
    exit 0
  fi
  sleep 5
done

exit 1
