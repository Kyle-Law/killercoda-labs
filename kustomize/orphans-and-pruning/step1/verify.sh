#!/bin/bash

# the resource must be gone from the render
R=$(kubectl kustomize /root/app 2>/dev/null)
[ -n "$R" ] || exit 1
echo "$R" | grep -q "name: legacy-flags" && exit 1
echo "$R" | grep -q "name: app-settings" || exit 1
echo "$R" | grep -q "name: feature-toggles" || exit 1

# the applied resources must exist
kubectl get configmap app-settings -n demo >/dev/null 2>&1 || exit 1
kubectl get configmap feature-toggles -n demo >/dev/null 2>&1 || exit 1

# and the orphan must STILL be in the cluster - that is the whole point
kubectl get configmap legacy-flags -n demo >/dev/null 2>&1 || exit 1

exit 0
