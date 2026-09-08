#!/bin/bash

# web's egress must now include a rule to api on 9898, alongside the DNS rule.
HAS_API_RULE=$(kubectl -n shop get netpol web-deny-egress -o json 2>/dev/null | python3 -c "
import json,sys
try:
    p=json.load(sys.stdin)
except Exception:
    sys.exit()
for rule in p.get('spec',{}).get('egress',[]):
    for peer in rule.get('to',[]):
        sel=peer.get('podSelector',{}).get('matchLabels',{})
        if sel.get('app')=='api':
            ports={ (pp.get('protocol'), pp.get('port')) for pp in rule.get('ports',[]) }
            if ('TCP',9898) in ports:
                print('yes')
" 2>/dev/null)
[ "$HAS_API_RULE" == "yes" ] || exit 1

# The restrictive ingress policy on api must have been removed again --
# leaving it in place would mean the outage was never actually resolved.
kubectl -n shop get netpol api-restrict-ingress >/dev/null 2>&1 && exit 1

for i in $(seq 1 12); do
  POD=$(kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }')
  [ -z "$POD" ] && { sleep 5; continue; }

  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null http://api:9898/ >/dev/null 2>&1
  [ "$?" == "0" ] && exit 0
  sleep 5
done

exit 1
