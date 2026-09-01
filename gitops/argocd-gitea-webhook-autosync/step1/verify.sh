#!/bin/bash

REPO=$(curl -s -u admin:AdminPass123! http://localhost:30300/api/v1/repos/admin/solar-system 2>/dev/null)
echo "$REPO" | grep -q '"empty":false' || exit 1

PRUNE=$(kubectl get application solar-system -n argocd -o jsonpath='{.spec.syncPolicy.automated.prune}' 2>/dev/null)
SELFHEAL=$(kubectl get application solar-system -n argocd -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null)
[ "$PRUNE" == "true" ] && [ "$SELFHEAL" == "true" ] || exit 1

for i in $(seq 1 30); do
  SYNC=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  HEALTH=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
  READY=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  IMAGE=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  if [ "$SYNC" == "Synced" ] && [ "$HEALTH" == "Healthy" ] && [ "$READY" == "2" ] && [ "$IMAGE" == "handafew/solar-system:v3" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
