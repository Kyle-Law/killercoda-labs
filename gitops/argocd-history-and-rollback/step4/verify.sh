#!/bin/bash

SPEC_PARAM=$(kubectl get application podinfo -n argocd -o jsonpath='{.spec.source.helm.parameters[0].value}' 2>/dev/null)
[ "$SPEC_PARAM" == "1" ] || exit 1

AUTOMATED=$(kubectl get application podinfo -n argocd -o jsonpath='{.spec.syncPolicy.automated}' 2>/dev/null)
[ -n "$AUTOMATED" ] || exit 1

for i in $(seq 1 24); do
  OUT=$(argocd app get podinfo --core 2>/dev/null)
  REPLICAS=$(kubectl -n default get deployment podinfo -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && [ "$REPLICAS" == "1" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
