#!/bin/bash

VALUES=$(helm get values podinfo-values2 2>/dev/null)
echo "$VALUES" | grep -q "replicaCount: 5" || exit 1
echo "$VALUES" | grep -q "from base" || exit 1
echo "$VALUES" | grep -q "from override" && exit 1

for i in $(seq 1 12); do
  REPLICAS=$(kubectl get deployment podinfo-values2 -o jsonpath='{.spec.replicas}' 2>/dev/null)
  READY=$(kubectl get deployment podinfo-values2 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$REPLICAS" == "5" ] && [ "$READY" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
