#!/bin/bash

HOOKS=$(curl -s -u admin:AdminPass123! http://localhost:30300/api/v1/repos/admin/solar-system/hooks 2>/dev/null)
echo "$HOOKS" | grep -q '"active":true' || exit 1
echo "$HOOKS" | grep -q "argocd-server.argocd.svc.cluster.local/api/webhook" || exit 1

for i in $(seq 1 30); do
  SYNC=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  IMAGE=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  if [ "$SYNC" == "Synced" ] && [ "$IMAGE" == "handafew/solar-system:v9" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
