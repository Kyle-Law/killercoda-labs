#!/bin/bash

# CRDs installed
kubectl get crd clusterqueues.kueue.x-k8s.io >/dev/null 2>&1 || exit 1
kubectl get crd localqueues.kueue.x-k8s.io >/dev/null 2>&1 || exit 1
kubectl get crd resourceflavors.kueue.x-k8s.io >/dev/null 2>&1 || exit 1

# controller genuinely running - the webhook must be up or later steps silently fail
for i in $(seq 1 36); do
  READY=$(kubectl get deployment kueue-controller-manager -n kueue-system \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
