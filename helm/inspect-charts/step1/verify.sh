#!/bin/bash

[ -s /root/values.yaml ] || exit 1

# Check structurally rather than diffing against a live 'helm show values'.
# The upstream chart publishes new versions over time, so an exact diff would
# start failing the moment the repo moves on - these top-level keys identify
# the nginx-ingress values file without depending on its version.
for key in "controller:" "rbac:" "prometheus:" "nginxServiceMesh:"; do
  grep -q "^${key}" /root/values.yaml || exit 1
done

# guard against someone saving a rendered manifest instead of a values file
if grep -qE '^(apiVersion|kind):' /root/values.yaml; then exit 1; fi

exit 0
