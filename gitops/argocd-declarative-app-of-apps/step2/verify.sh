#!/bin/bash

for i in $(seq 1 30); do
  DEV=$(kubectl -n podinfo-dev get deployment podinfo-dev -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  STAGING=$(kubectl -n podinfo-staging get deployment podinfo-staging -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  PROD=$(kubectl -n podinfo-prod get deployment podinfo-prod -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ "$DEV" == "1" ] && [ "$STAGING" == "2" ] && [ "$PROD" == "3" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
