#!/bin/bash

R=$(kubectl kustomize /root/app/overlay 2>/dev/null)
[ -n "$R" ] || exit 1

# the intended change landed
echo "$R" | grep -A1 "name: LOG_LEVEL" | grep -qE 'value: "?debug"?' || exit 1

# and the merge preserved everything else
echo "$R" | grep -q "name: KEEP_ME" || exit 1
echo "$R" | grep -q "name: logger" || exit 1
echo "$R" | grep -q "image: nginx:1.27-alpine" || exit 1

# still exactly two containers - a mis-keyed patch would have added a third.
# container names sit at 8-space indent; env/port names carry a "- " marker.
COUNT=$(echo "$R" | grep -cE "^        name: ")
[ "$COUNT" == "2" ] || exit 1

exit 0
