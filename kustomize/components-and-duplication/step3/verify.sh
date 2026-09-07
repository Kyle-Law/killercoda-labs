#!/bin/bash

[ -f /root/app/components/ha/kustomization.yaml ] || exit 1
grep -q "kind: Component" /root/app/components/ha/kustomization.yaml || exit 1

P=$(kubectl kustomize /root/app/overlays/prod 2>/dev/null)
S=$(kubectl kustomize /root/app/overlays/staging 2>/dev/null)
[ -n "$P" ] && [ -n "$S" ] || exit 1

# prod: both features
echo "$P" | grep -qE "^  replicas: 3$" || exit 1
echo "$P" | grep -q 'prometheus.io/port: "9102"' || exit 1

# staging: monitoring only, and NOT scaled - proving the component is opt-in
echo "$S" | grep -qE "^  replicas: 1$" || exit 1
echo "$S" | grep -q 'prometheus.io/port: "9102"' || exit 1

# and staging must not be referencing the ha component
grep -q "components/ha" /root/app/overlays/staging/kustomization.yaml && exit 1

exit 0
