#!/bin/bash

PRESYNC_COUNT=$(kubectl -n default get job -o name 2>/dev/null | grep -c upgrade-sql-schema)
[ "$PRESYNC_COUNT" -ge 2 ] 2>/dev/null || exit 1

for i in $(seq 1 24); do
  UP_JOB=$(kubectl -n default get job maint-page-up -o jsonpath='{.status.succeeded}' 2>/dev/null)
  DOWN_JOB=$(kubectl -n default get job maint-page-down -o jsonpath='{.status.succeeded}' 2>/dev/null)
  if [ "$UP_JOB" == "1" ] && [ "$DOWN_JOB" == "1" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
