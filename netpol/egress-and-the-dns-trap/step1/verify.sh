#!/bin/bash

webpod() {
  kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }'
}

# A policy selecting web, naming Egress, with no egress rules at all.
POLICY=$(kubectl -n shop get netpol -o json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d.get('items',[]):
    s=p['spec']
    sel=s.get('podSelector',{}).get('matchLabels',{})
    if sel.get('app')=='web' and 'Egress' in s.get('policyTypes',[]) and not s.get('egress'):
        print('yes'); break
" 2>/dev/null)
[ "$POLICY" == "yes" ] || exit 1

for i in $(seq 1 12); do
  POD=$(webpod)
  [ -z "$POD" ] && { sleep 5; continue; }

  # DNS itself must be blocked...
  kubectl -n shop exec "$POD" -- nslookup api.shop.svc.cluster.local >/dev/null 2>&1
  DNS_OK=$?

  # ...and so must a direct, DNS-free connection to api's ClusterIP.
  IP=$(kubectl -n shop get svc api -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null "http://$IP:9898/" >/dev/null 2>&1
  RAW_OK=$?

  if [ "$DNS_OK" != "0" ] && [ "$RAW_OK" != "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
