#!/bin/bash

VALUES_OBJ=$(kubectl get application podinfo-helm -n argocd -o jsonpath='{.spec.source.helm.valuesObject}' 2>/dev/null)
echo "$VALUES_OBJ" | grep -q '"replicaCount":3' || exit 1
echo "$VALUES_OBJ" | grep -q "from argocd inline values" || exit 1

for i in $(seq 1 24); do
  OUT=$(argocd app get podinfo-helm --core 2>/dev/null)
  REPLICAS=$(kubectl -n default get deployment podinfo-helm -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && [ "$REPLICAS" == "3" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
