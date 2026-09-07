#!/bin/bash

# a JSON 6902 patch must be doing the work
grep -q "op: remove" /root/app/overlay/kustomization.yaml 2>/dev/null || exit 1

R=$(kubectl kustomize /root/app/overlay 2>/dev/null)
# the restored, working state must build - the step ends by restoring it
[ -n "$R" ] || exit 1

echo "$R" | grep -qE "^  replicas: 3$" || exit 1
echo "$R" | grep -q "name: KEEP_ME" && exit 1
echo "$R" | grep -q "name: LOG_LEVEL" || exit 1

# the logger patch must still be present - it is what makes the index correct,
# and removing it is the failure the step demonstrates
echo "$R" | grep -q "echo tock" || exit 1

COUNT=$(echo "$R" | grep -cE "^        name: ")
[ "$COUNT" == "2" ] || exit 1

exit 0
