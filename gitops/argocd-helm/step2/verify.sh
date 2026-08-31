#!/bin/bash

FORCE_STRING=$(kubectl get application podinfo-helm -n argocd -o jsonpath='{.spec.source.helm.parameters[?(@.name=="podAnnotations.build")].forceString}' 2>/dev/null)
[ "$FORCE_STRING" == "true" ] || exit 1

for i in $(seq 1 24); do
  OUT=$(argocd app get podinfo-helm --core 2>/dev/null)
  REPLICAS=$(kubectl -n default get deployment podinfo-helm -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && [ "$REPLICAS" == "2" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
