#!/bin/bash

for i in $(seq 1 24); do
  P0=$(kubectl get application podinfo -n argocd -o jsonpath='{.status.history[?(@.id==0)].source.helm.parameters[0].value}' 2>/dev/null)
  P1=$(kubectl get application podinfo -n argocd -o jsonpath='{.status.history[?(@.id==1)].source.helm.parameters[0].value}' 2>/dev/null)
  P2=$(kubectl get application podinfo -n argocd -o jsonpath='{.status.history[?(@.id==2)].source.helm.parameters[0].value}' 2>/dev/null)
  REPLICAS=$(kubectl -n default get deployment podinfo -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ "$P0" == "1" ] && [ "$P1" == "2" ] && [ "$P2" == "3" ] && [ "$REPLICAS" == "3" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
