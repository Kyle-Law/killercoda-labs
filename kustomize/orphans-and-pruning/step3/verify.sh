#!/bin/bash

# the label must be applied by the kustomization, not by hand
grep -qE "^labels:" /root/app/kustomization.yaml 2>/dev/null || exit 1
R=$(kubectl kustomize /root/app 2>/dev/null)
[ -n "$R" ] || exit 1
echo "$R" | grep -q "managed-by: app-kustomize" || exit 1

# the managed resources must still be present and labelled in-cluster
for c in app-settings feature-toggles; do
  kubectl get configmap "$c" -n demo >/dev/null 2>&1 || exit 1
  L=$(kubectl get configmap "$c" -n demo -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null)
  [ "$L" == "app-kustomize" ] || exit 1
done

# and the orphan must finally be gone
if kubectl get configmap legacy-flags -n demo >/dev/null 2>&1; then exit 1; fi

exit 0
