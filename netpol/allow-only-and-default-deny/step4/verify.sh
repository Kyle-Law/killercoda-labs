#!/bin/bash

reach() {
  POD=$(kubectl -n shop get pods -l app="$1" --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }')
  [ -z "$POD" ] && return 2
  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null "http://$2:9898/" 2>/dev/null
}

kubectl -n shop get deployment metrics >/dev/null 2>&1 || exit 1

for i in $(seq 1 15); do
  # The three intended paths.
  reach web api;     WEB_API=$?
  reach api db;      API_DB=$?
  reach metrics api; MET_API=$?

  # metrics must accept nothing, and must not have gained reach to db.
  reach web metrics; WEB_MET=$?
  reach api metrics; API_MET=$?
  reach metrics db;  MET_DB=$?

  # Earlier restrictions must still hold.
  reach db api;      DB_API=$?
  reach web db;      WEB_DB=$?
  reach api web;     API_WEB=$?

  if [ "$WEB_API" == "0" ] && [ "$API_DB" == "0" ] && [ "$MET_API" == "0" ] \
     && [ "$WEB_MET" != "0" ] && [ "$API_MET" != "0" ] && [ "$MET_DB" != "0" ] \
     && [ "$DB_API" != "0" ] && [ "$WEB_DB" != "0" ] && [ "$API_WEB" != "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
