#!/bin/bash

[ -s /root/survivors.txt ] || exit 1

# the unrelated resource must have been created and then destroyed by prune -
# that is the demonstration
if kubectl get configmap other-team-config -n demo >/dev/null 2>&1; then exit 1; fi
grep -qx "other-team-config" /root/survivors.txt && exit 1

# the kustomization's own resources must have survived
for c in app-settings feature-toggles; do
  kubectl get configmap "$c" -n demo >/dev/null 2>&1 || exit 1
  grep -qx "$c" /root/survivors.txt || exit 1
done

# and the earlier orphan must still be gone
grep -qx "legacy-flags" /root/survivors.txt && exit 1

exit 0
