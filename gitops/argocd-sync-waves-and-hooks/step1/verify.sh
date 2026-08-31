#!/bin/bash

get_ts() {
  kubectl -n default get "$1" "$2" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null
}

for i in $(seq 1 24); do
  PRESYNC=$(kubectl -n default get job -o name 2>/dev/null | grep upgrade-sql-schema | head -1 | sed 's|job.batch/||')
  if [ -n "$PRESYNC" ]; then
    T_PRESYNC=$(get_ts job "$PRESYNC")
    T_BACKEND=$(get_ts replicaset backend)
    T_UP=$(get_ts job maint-page-up)
    T_FRONTEND=$(get_ts replicaset frontend)
    T_DOWN=$(get_ts job maint-page-down)
    if [ -n "$T_PRESYNC" ] && [ -n "$T_BACKEND" ] && [ -n "$T_UP" ] && [ -n "$T_FRONTEND" ] && [ -n "$T_DOWN" ] && \
       [ "$T_PRESYNC" \< "$T_BACKEND" ] && [ "$T_BACKEND" \< "$T_UP" ] && [ "$T_UP" \< "$T_FRONTEND" ] && [ "$T_FRONTEND" \< "$T_DOWN" ]; then
      exit 0
    fi
  fi
  sleep 5
done

exit 1
