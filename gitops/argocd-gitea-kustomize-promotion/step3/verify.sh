#!/bin/bash

grep -q "newTag: v2" /root/solar-kustomize/overlays/prod/kustomization.yaml 2>/dev/null || exit 1

cd /root/solar-kustomize 2>/dev/null || exit 1
git diff --quiet HEAD -- overlays/prod/kustomization.yaml || exit 1

for i in $(seq 1 30); do
  S=$(kubectl get deploy solar-system -n staging -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  P=$(kubectl get deploy solar-system -n prod    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  R=$(kubectl get deploy solar-system -n prod -o jsonpath='{.spec.replicas}' 2>/dev/null)
  # both promoted, and prod's own overlay setting survived the promotion
  if [ "$S" == "handafew/solar-system:v2" ] && [ "$P" == "handafew/solar-system:v2" ] && [ "$R" == "2" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
