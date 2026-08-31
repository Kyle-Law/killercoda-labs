#!/bin/bash

for i in $(seq 1 30); do
  SYNC=$(kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  IMAGE=$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  if [ "$SYNC" == "Synced" ] && [ "$IMAGE" == "siddharth67/solar-system:v3" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
