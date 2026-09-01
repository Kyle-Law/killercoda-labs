#!/bin/bash

for i in $(seq 1 30); do
  REPLICAS=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.spec.replicas}' 2>/dev/null)
  READY=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  SYNC=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  if [ "$REPLICAS" == "2" ] && [ "$READY" == "2" ] && [ "$SYNC" == "Synced" ]; then
    exit 0
  fi
  sleep 3
done

exit 1
