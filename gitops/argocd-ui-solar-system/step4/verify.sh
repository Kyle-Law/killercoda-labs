#!/bin/bash

AUTOMATED=$(kubectl get application solar-system -n argocd -o jsonpath='{.spec.syncPolicy.automated}' 2>/dev/null)
[ -n "$AUTOMATED" ] || exit 1

SELFHEAL=$(kubectl get application solar-system -n argocd -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null)
[ "$SELFHEAL" == "true" ] || exit 1

for i in $(seq 1 30); do
  SYNC=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  HEALTH=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
  IMAGE=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  if [ "$SYNC" == "Synced" ] && [ "$HEALTH" == "Healthy" ] && [ "$IMAGE" == "handafew/solar-system:v3" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
