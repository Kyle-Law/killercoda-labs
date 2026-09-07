#!/bin/bash

RENDER=$(kubectl kustomize /root/app/prod 2>/dev/null)
[ -n "$RENDER" ] || exit 1

# the arg must carry the prefixed name AND keep its flag intact - a whole-field
# overwrite would have produced a bare "prod-backend" with no --upstream=
echo "$RENDER" | grep -q -- "--upstream=prod-backend" || exit 1

# the delimiter option must actually be in use, not the flag hardcoded into
# the patch, which would pass the check above without demonstrating anything
grep -q "delimiter:" /root/app/prod/kustomization.yaml 2>/dev/null || exit 1
if grep -q -- "--upstream=prod-backend" /root/app/prod/deploy-patch.yaml 2>/dev/null; then exit 1; fi

# the earlier ConfigMap replacement must still hold
echo "$RENDER" | grep -qE 'BACKEND_HOST: "?prod-backend"?' || exit 1

# and no stale bare reference may remain anywhere in the render
if echo "$RENDER" | grep -E "(^|[^-])backend" | grep -v "prod-backend" | grep -qE "BACKEND_HOST|upstream"; then
  exit 1
fi

exit 0
