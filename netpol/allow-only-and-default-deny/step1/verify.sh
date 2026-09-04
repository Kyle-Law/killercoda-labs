#!/bin/bash

reach() {
  POD=$(kubectl -n shop get pods -l app="$1" --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }')
  [ -z "$POD" ] && return 2
  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null "http://$2:9898/" 2>/dev/null
}

# Exactly one policy, selecting api.
COUNT=$(kubectl -n shop get netpol --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT" == "1" ] || exit 1

for i in $(seq 1 12); do
  # api must now reject db but still accept web...
  reach web api;  WEB_API=$?
  reach db api;   DB_API=$?
  # ...and the Pods no policy selects must be untouched.
  reach web db;   WEB_DB=$?
  reach api db;   API_DB=$?
  reach db web;   DB_WEB=$?

  if [ "$WEB_API" == "0" ] && [ "$DB_API" != "0" ] \
     && [ "$WEB_DB" == "0" ] && [ "$API_DB" == "0" ] && [ "$DB_WEB" == "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
