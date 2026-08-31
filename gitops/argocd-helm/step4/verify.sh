#!/bin/bash

VALUES_FILE=$(kubectl get application helm-guestbook -n argocd -o jsonpath='{.spec.source.helm.valueFiles[0]}' 2>/dev/null)
[ "$VALUES_FILE" == "values-production.yaml" ] || exit 1

for i in $(seq 1 24); do
  OUT=$(argocd app get helm-guestbook --core 2>/dev/null)
  SVC_TYPE=$(kubectl -n default get svc helm-guestbook -o jsonpath='{.spec.type}' 2>/dev/null)
  DEPLOY_READY=$(kubectl -n default get deployment helm-guestbook -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  # values-production.yaml sets service.type: LoadBalancer, which never gets an
  # external IP on a bare cluster -- Argo CD's Service health check stays
  # "Progressing" forever for that reason alone, so check the Deployment's own
  # health and the Service's spec directly instead of overall app health.
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && [ "$SVC_TYPE" == "LoadBalancer" ] && [ "$DEPLOY_READY" -ge 1 ] 2>/dev/null; then
    exit 0
  fi
  sleep 5
done

exit 1
