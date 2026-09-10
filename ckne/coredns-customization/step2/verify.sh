#!/bin/bash

# The zone has to resolve through cluster DNS -- asking the corporate resolver
# directly would have worked before the change and proves nothing.
for _ in $(seq 1 30); do
  DB=$(kubectl exec dnstools -- dig +short db.corp.internal 2>/dev/null | tr -d '[:space:]')

  if [ "$DB" == "10.99.0.42" ]; then
    # ...and the rest of DNS must still work. A forward in the wrong block
    # would resolve corp.internal and break everything else.
    WEB=$(kubectl exec dnstools -- dig +short web.default.svc.cluster.local 2>/dev/null | tr -d '[:space:]')
    CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    [ -n "$WEB" ] && [ "$WEB" == "$CLUSTER_IP" ] && exit 0
  fi
  sleep 5
done

exit 1
