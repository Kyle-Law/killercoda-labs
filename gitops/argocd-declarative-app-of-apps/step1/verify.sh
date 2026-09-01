#!/bin/bash

for i in $(seq 1 30); do
  PARENT_SYNC=$(kubectl get application app-of-apps -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  DEV_SYNC=$(kubectl get application podinfo-dev -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  STAGING_SYNC=$(kubectl get application podinfo-staging -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  DEV_REPLICAS=$(kubectl -n podinfo-dev get deployment podinfo-dev -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  STAGING_REPLICAS=$(kubectl -n podinfo-staging get deployment podinfo-staging -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  if [ "$PARENT_SYNC" == "Synced" ] && [ "$DEV_SYNC" == "Synced" ] && [ "$STAGING_SYNC" == "Synced" ] \
     && [ "$DEV_REPLICAS" == "1" ] && [ "$STAGING_REPLICAS" == "2" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
