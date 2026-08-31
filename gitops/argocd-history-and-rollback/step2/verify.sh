#!/bin/bash

for i in $(seq 1 24); do
  P3=$(kubectl get application podinfo -n argocd -o jsonpath='{.status.history[?(@.id==3)].source.helm.parameters[0].value}' 2>/dev/null)
  REPLICAS=$(kubectl -n default get deployment podinfo -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ "$P3" == "1" ] && [ "$REPLICAS" == "1" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
