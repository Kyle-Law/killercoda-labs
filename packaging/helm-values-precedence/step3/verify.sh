#!/bin/bash

PLAIN=$(helm get values podinfo-values3 2>/dev/null)
FULL=$(helm get values podinfo-values3 -a 2>/dev/null)

echo "$PLAIN" | grep -q "replicaCount: 2" || exit 1
echo "$PLAIN" | grep -q "logLevel: debug" || exit 1
echo "$PLAIN" | grep -q "resources:" && exit 1
echo "$FULL" | grep -q "resources:" || exit 1

for i in $(seq 1 12); do
  REPLICAS=$(kubectl get deployment podinfo-values3 -o jsonpath='{.spec.replicas}' 2>/dev/null)
  READY=$(kubectl get deployment podinfo-values3 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$REPLICAS" == "2" ] && [ "$READY" == "2" ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
