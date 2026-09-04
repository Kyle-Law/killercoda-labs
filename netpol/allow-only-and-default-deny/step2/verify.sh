#!/bin/bash

reach() {
  POD=$(kubectl -n shop get pods -l app="$1" --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }')
  [ -z "$POD" ] && return 2
  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null "http://$2:9898/" 2>/dev/null
}

# A policy protecting db must exist, and it must govern Ingress only --
# leaving Egress out is the whole point of the step.
DB_POL=$(kubectl -n shop get netpol -o json 2>/dev/null \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d.get('items',[]):
    sel=p['spec'].get('podSelector',{}).get('matchLabels',{})
    if sel.get('app')=='db':
        print(p['metadata']['name'], ','.join(p['spec'].get('policyTypes',[])))
" 2>/dev/null)
[ -n "$DB_POL" ] || exit 1
echo "$DB_POL" | grep -q "Egress" && exit 1
echo "$DB_POL" | grep -q "Ingress" || exit 1

for i in $(seq 1 12); do
  reach api db;  API_DB=$?
  reach web db;  WEB_DB=$?
  reach db web;  DB_WEB=$?   # db's own egress must still work
  reach web api; WEB_API=$?  # step 1's policy must still hold

  if [ "$API_DB" == "0" ] && [ "$WEB_DB" != "0" ] \
     && [ "$DB_WEB" == "0" ] && [ "$WEB_API" == "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
