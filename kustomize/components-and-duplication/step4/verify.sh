#!/bin/bash

[ -f /root/app/components/burst/kustomization.yaml ] || exit 1
grep -q "replicas: 10" /root/app/components/burst/kustomization.yaml || exit 1

K=/root/app/overlays/prod/kustomization.yaml

# BOTH components must be listed - dropping burst would satisfy a naive
# replica check without demonstrating the ordering rule at all
grep -q "components/burst" "$K" || exit 1
grep -q "components/ha" "$K" || exit 1

# ha must come AFTER burst, which is what makes 3 win
BURST_LINE=$(grep -n "components/burst" "$K" | cut -d: -f1)
HA_LINE=$(grep -n "components/ha" "$K" | cut -d: -f1)
[ -n "$BURST_LINE" ] && [ -n "$HA_LINE" ] || exit 1
[ "$HA_LINE" -gt "$BURST_LINE" ] || exit 1

# and the rendered result must actually be 3
R=$(kubectl kustomize /root/app/overlays/prod 2>/dev/null)
echo "$R" | grep -qE "^  replicas: 3$" || exit 1

exit 0
