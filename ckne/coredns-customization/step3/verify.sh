#!/bin/bash

CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$CLUSTER_IP" ] || exit 1

for _ in $(seq 1 30); do
  LEGACY=$(kubectl exec dnstools -- dig +short legacy-api.example.com 2>/dev/null | tr -d '[:space:]')

  if [ "$LEGACY" == "$CLUSTER_IP" ]; then
    # The rewrite must not have cost anything that already worked.
    WEB=$(kubectl exec dnstools -- dig +short web.default.svc.cluster.local 2>/dev/null | tr -d '[:space:]')
    DB=$(kubectl exec dnstools -- dig +short db.corp.internal 2>/dev/null | tr -d '[:space:]')
    [ "$WEB" == "$CLUSTER_IP" ] && [ "$DB" == "10.99.0.42" ] && exit 0
  fi
  sleep 5
done

exit 1
