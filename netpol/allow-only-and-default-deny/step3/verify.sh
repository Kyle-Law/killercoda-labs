#!/bin/bash

reach() {
  POD=$(kubectl -n shop get pods -l app="$1" --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }')
  [ -z "$POD" ] && return 2
  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null "http://$2:9898/" 2>/dev/null
}

# A namespace-wide ingress deny must exist: empty podSelector, Ingress named,
# and no ingress rules of its own.
HAS_DENY=$(kubectl -n shop get netpol -o json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d.get('items',[]):
    s=p['spec']
    sel=s.get('podSelector',{})
    if sel in ({}, {'matchLabels':{}}) or not sel:
        if 'Ingress' in s.get('policyTypes',[]) and not s.get('ingress'):
            print('yes'); break
" 2>/dev/null)
[ "$HAS_DENY" == "yes" ] || exit 1

for i in $(seq 1 12); do
  # The two earlier allows must have survived the deny-all...
  reach web api; WEB_API=$?
  reach api db;  API_DB=$?
  # ...and everything else must now be closed, web included.
  reach api web; API_WEB=$?
  reach db web;  DB_WEB=$?
  reach web db;  WEB_DB=$?
  reach db api;  DB_API=$?

  if [ "$WEB_API" == "0" ] && [ "$API_DB" == "0" ] \
     && [ "$API_WEB" != "0" ] && [ "$DB_WEB" != "0" ] \
     && [ "$WEB_DB" != "0" ] && [ "$DB_API" != "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
