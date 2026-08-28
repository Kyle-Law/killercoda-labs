#!/bin/bash

export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}

for i in $(seq 1 12); do
  helm status happy-panda >/dev/null 2>&1 && exit 0
  sleep 5
done

exit 1
