#!/bin/bash

# the component must exist and declare the right kind
[ -f /root/app/components/monitoring/kustomization.yaml ] || exit 1
grep -q "kind: Component" /root/app/components/monitoring/kustomization.yaml || exit 1

# the duplicated copies must be gone - that is the point
[ -f /root/app/overlays/prod/monitoring-patch.yaml ] && exit 1
[ -f /root/app/overlays/staging/monitoring-patch.yaml ] && exit 1

# both overlays must include it via components:, not resources:
for e in staging prod; do
  grep -q "^components:" /root/app/overlays/$e/kustomization.yaml || exit 1
done

# and the rendered result must be unchanged from step 1
for e in staging prod; do
  R=$(kubectl kustomize /root/app/overlays/$e 2>/dev/null)
  [ -n "$R" ] || exit 1
  echo "$R" | grep -q 'prometheus.io/port: "9102"' || exit 1
  echo "$R" | grep -q "name: ${e}-web" || exit 1
done

exit 0
