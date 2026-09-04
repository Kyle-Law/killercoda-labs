#!/bin/bash

# A prod overlay must exist, referencing the same base.
[ -f /root/app/overlays/prod/kustomization.yaml ] || exit 1
grep -q "prod-" /root/app/overlays/prod/kustomization.yaml || exit 1

# The image bump must have happened in the base, not in either overlay.
grep -q "podinfo:6.6.0" /root/app/base/deployment.yaml || exit 1
grep -q "6.6.0" /root/app/overlays/dev/kustomization.yaml 2>/dev/null && exit 1
grep -q "6.6.0" /root/app/overlays/prod/kustomization.yaml 2>/dev/null && exit 1

for i in $(seq 1 30); do
  DEV_READY=$(kubectl get deployment dev-shop -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  PROD_READY=$(kubectl get deployment prod-shop -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  DEV_IMG=$(kubectl get deployment dev-shop -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  PROD_IMG=$(kubectl get deployment prod-shop -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  # Both environments on the new image, each keeping its own replica count.
  if [ "$DEV_READY" == "2" ] && [ "$PROD_READY" == "3" ] \
     && [ "$DEV_IMG" == "stefanprodan/podinfo:6.6.0" ] \
     && [ "$PROD_IMG" == "stefanprodan/podinfo:6.6.0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
