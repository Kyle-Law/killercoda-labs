#!/bin/bash

webpod() {
  kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }'
}

# The DNS rule must exist, scoped by namespace AND pod label together (an
# AND, one list entry) -- not the broader OR shape that's the point of
# step 4.
HAS_RULE=$(kubectl -n shop get netpol web-deny-egress -o json 2>/dev/null | python3 -c "
import json,sys
try:
    p=json.load(sys.stdin)
except Exception:
    sys.exit()
for rule in p.get('spec',{}).get('egress',[]):
    for peer in rule.get('to',[]):
        ns=peer.get('namespaceSelector',{}).get('matchLabels',{})
        pod=peer.get('podSelector',{}).get('matchLabels',{})
        if ns.get('kubernetes.io/metadata.name')=='kube-system' and pod.get('k8s-app')=='kube-dns':
            ports={ (pp.get('protocol'), pp.get('port')) for pp in rule.get('ports',[]) }
            if ('UDP',53) in ports and ('TCP',53) in ports:
                print('yes')
" 2>/dev/null)
[ "$HAS_RULE" == "yes" ] || exit 1

for i in $(seq 1 12); do
  POD=$(webpod)
  [ -z "$POD" ] && { sleep 5; continue; }

  # DNS must now work...
  kubectl -n shop exec "$POD" -- nslookup api.shop.svc.cluster.local >/dev/null 2>&1
  DNS_OK=$?

  # ...but the actual request must still fail -- that's the point of the step.
  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null http://api:9898/ >/dev/null 2>&1
  APP_OK=$?

  if [ "$DNS_OK" == "0" ] && [ "$APP_OK" != "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
