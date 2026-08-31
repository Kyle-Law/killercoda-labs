#!/bin/bash

for i in $(seq 1 30); do
  SYNC=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  HEALTH=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
  READY=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  SVC_TYPE=$(kubectl -n solar-system get svc solar-system -o jsonpath='{.spec.type}' 2>/dev/null)
  NODEPORT=$(kubectl -n solar-system get svc solar-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
  if [ "$SYNC" == "Synced" ] && [ "$HEALTH" == "Healthy" ] && [ "$READY" == "2" ] && \
     [ "$SVC_TYPE" == "NodePort" ] && [ "$NODEPORT" == "30090" ]; then
    CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:30090/" 2>/dev/null)
    [ "$CODE" == "200" ] && exit 0
  fi
  sleep 5
done

exit 1
