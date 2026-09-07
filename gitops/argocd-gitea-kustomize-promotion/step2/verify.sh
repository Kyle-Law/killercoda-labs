#!/bin/bash

# staging must be on v2 in the repo AND in the cluster
grep -q "newTag: v2" /root/solar-kustomize/overlays/staging/kustomization.yaml 2>/dev/null || exit 1

# the change must actually be committed - an uncommitted edit would never
# reach Argo CD
cd /root/solar-kustomize 2>/dev/null || exit 1
git diff --quiet HEAD -- overlays/staging/kustomization.yaml || exit 1

for i in $(seq 1 30); do
  S=$(kubectl get deploy solar-system -n staging -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  P=$(kubectl get deploy solar-system -n prod    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  # staging promoted, prod deliberately left behind
  if [ "$S" == "handafew/solar-system:v2" ] && [ "$P" == "handafew/solar-system:v1" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
