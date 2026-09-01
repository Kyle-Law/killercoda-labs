#!/bin/bash

for i in $(seq 1 30); do
  if ! kubectl get application podinfo-dev -n argocd >/dev/null 2>&1; then
    if ! kubectl -n podinfo-dev get deployment podinfo-dev >/dev/null 2>&1; then
      kubectl get ns podinfo-dev >/dev/null 2>&1 && exit 0
    fi
  fi
  sleep 5
done

exit 1
