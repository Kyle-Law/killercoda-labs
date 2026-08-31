#!/bin/bash

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh
fi

helm repo add podinfo https://stefanprodan.github.io/podinfo >/dev/null 2>&1
helm repo update >/dev/null 2>&1

helm install podinfo podinfo/podinfo --version 6.5.4 --wait --timeout 90s

touch /tmp/step1-applied
