#!/bin/bash

# The overlay must carry the change...
grep -q "count: *2" /root/app/overlays/dev/kustomization.yaml 2>/dev/null || exit 1

# ...and the base must be untouched, which is the point of the step.
grep -q "replicas: *1" /root/app/base/deployment.yaml 2>/dev/null || exit 1

# The rendered overlay must still be prefixed.
kubectl kustomize /root/app/overlays/dev 2>/dev/null | grep -q "name: dev-shop" || exit 1

for i in $(seq 1 30); do
  READY=$(kubectl get deployment dev-shop -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && exit 0
  sleep 5
done

exit 1
