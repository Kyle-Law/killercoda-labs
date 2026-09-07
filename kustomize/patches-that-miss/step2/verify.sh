#!/bin/bash

# The learner must have SEEN the three-container render. The step ends by
# cleaning up, so accept either state: the mis-keyed patch still present and
# producing three containers, or the cleanup already done.
R=$(kubectl kustomize /root/app/overlay 2>/dev/null)
[ -n "$R" ] || exit 1

COUNT=$(echo "$R" | grep -cE "^        name: ")

if [ "$COUNT" == "3" ]; then
  # mid-step: the phantom container must be the mis-keyed one
  echo "$R" | grep -q "name: aap" || exit 1
  echo "$R" | grep -q "DOESNOTEXIST" || exit 1
  exit 0
fi

if [ "$COUNT" == "2" ]; then
  # cleaned up: the typo patch must be gone and the good patch still in place
  [ -f /root/app/overlay/typo-patch.yaml ] && exit 1
  echo "$R" | grep -q "name: aap" && exit 1
  echo "$R" | grep -A1 "name: LOG_LEVEL" | grep -qE 'value: "?debug"?' || exit 1
  exit 0
fi

exit 1
