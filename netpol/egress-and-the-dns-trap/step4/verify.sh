#!/bin/bash

# The final state must be the correctly-scoped AND rule -- namespace and
# pod label together, in the same list entry -- not the broader OR shape
# this step exists to demonstrate the danger of.
FINAL_OK=$(kubectl -n shop get netpol web-deny-egress -o json 2>/dev/null | python3 -c "
import json,sys
try:
    p=json.load(sys.stdin)
except Exception:
    sys.exit()
found_dns_and=False
found_api=False
for rule in p.get('spec',{}).get('egress',[]):
    for peer in rule.get('to',[]):
        ns=peer.get('namespaceSelector',{}).get('matchLabels',{})
        pod=peer.get('podSelector',{}).get('matchLabels',{})
        if ns.get('kubernetes.io/metadata.name')=='kube-system' and pod.get('k8s-app')=='kube-dns':
            found_dns_and=True
        if pod.get('app')=='api':
            found_api=True
if found_dns_and and found_api:
    print('yes')
" 2>/dev/null)
[ "$FINAL_OK" == "yes" ] || exit 1

for i in $(seq 1 12); do
  POD=$(kubectl -n shop get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' '$2 == "" { print $1; exit }')
  [ -z "$POD" ] && { sleep 5; continue; }

  # DNS and the real app call must both still work...
  kubectl -n shop exec "$POD" -- nslookup api.shop.svc.cluster.local >/dev/null 2>&1
  DNS_OK=$?
  kubectl -n shop exec "$POD" -- wget -q -T 3 -O /dev/null http://api:9898/ >/dev/null 2>&1
  APP_OK=$?

  # ...but the wider, non-DNS peer in kube-system must be unreachable again.
  PEER_IP=$(kubectl -n kube-system get pods -o json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
node_ips=set()
try:
    nodes=json.loads('''$(kubectl get nodes -o json 2>/dev/null)''')
    node_ips={a['address'] for n in nodes['items'] for a in n['status'].get('addresses',[]) if a['type']=='InternalIP'}
except Exception:
    pass
for p in d.get('items',[]):
    labels=p['metadata'].get('labels',{})
    if labels.get('k8s-app')=='kube-dns':
        continue
    if p['spec'].get('hostNetwork'):
        continue
    ip=p['status'].get('podIP')
    if ip and ip not in node_ips:
        print(ip); break
" 2>/dev/null)

  PEER_BLOCKED=1
  if [ -n "$PEER_IP" ]; then
    kubectl -n shop exec "$POD" -- nc -zv -w 3 "$PEER_IP" 53 2>&1 | grep -q "timed out" && PEER_BLOCKED=0
  else
    PEER_BLOCKED=0
  fi

  if [ "$DNS_OK" == "0" ] && [ "$APP_OK" == "0" ] && [ "$PEER_BLOCKED" == "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
