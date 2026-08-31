#!/bin/bash

for i in $(seq 1 24); do
  OUT=$(argocd app get kustomize-guestbook --core 2>/dev/null)
  IMG=$(kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  REPLICAS=$(kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if echo "$OUT" | grep -q "^Sync Status:.*Synced" && echo "$OUT" | grep -q "^Health Status:.*Healthy" && \
     [ "$IMG" == "nginx:1.27-alpine" ] && [ "$REPLICAS" == "3" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
