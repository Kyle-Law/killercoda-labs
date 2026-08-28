#!/bin/bash

command -v helm >/dev/null 2>&1 || exit 1
command -v kubectl >/dev/null 2>&1 || exit 1

export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}

# helm must be able to reach the cluster, not just exist on PATH
for i in $(seq 1 12); do
  helm ls >/dev/null 2>&1 && exit 0
  sleep 5
done

exit 1
