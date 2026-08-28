#!/bin/bash

VALUES=$(helm get values podinfo-values1 2>/dev/null)
echo "$VALUES" | grep -q "replicaCount: 2" || exit 1
echo "$VALUES" | grep -q "hello from values1" || exit 1
echo "$VALUES" | grep -q "logLevel" && exit 1

for i in $(seq 1 12); do
  REPLICAS=$(kubectl get deployment podinfo-values1 -o jsonpath='{.spec.replicas}' 2>/dev/null)
  READY=$(kubectl get deployment podinfo-values1 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$REPLICAS" == "2" ] && [ "$READY" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
