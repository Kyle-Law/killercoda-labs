#!/bin/bash

# both Applications must exist and point at the SAME repo, different paths
for app in solar-staging solar-prod; do
  kubectl -n argocd get application "$app" >/dev/null 2>&1 || exit 1
done
RS=$(kubectl -n argocd get application solar-staging -o jsonpath='{.spec.source.repoURL}' 2>/dev/null)
RP=$(kubectl -n argocd get application solar-prod    -o jsonpath='{.spec.source.repoURL}' 2>/dev/null)
[ -n "$RS" ] && [ "$RS" == "$RP" ] || exit 1

PS=$(kubectl -n argocd get application solar-staging -o jsonpath='{.spec.source.path}' 2>/dev/null)
PP=$(kubectl -n argocd get application solar-prod    -o jsonpath='{.spec.source.path}' 2>/dev/null)
[ "$PS" == "overlays/staging" ] || exit 1
[ "$PP" == "overlays/prod" ] || exit 1

# and both must have actually synced their workloads
for i in $(seq 1 30); do
  SD=$(kubectl get deploy solar-system -n staging -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  PD=$(kubectl get deploy solar-system -n prod    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ "${SD:-0}" -ge 1 ] 2>/dev/null && [ "${PD:-0}" -ge 2 ] 2>/dev/null; then exit 0; fi
  sleep 5
done

exit 1
