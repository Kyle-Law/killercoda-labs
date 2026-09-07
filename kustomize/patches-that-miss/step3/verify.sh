#!/bin/bash

R=$(kubectl kustomize /root/app/overlay 2>/dev/null)
[ -n "$R" ] || exit 1

# the command must have been replaced with the tock variant
echo "$R" | grep -q "echo tock" || exit 1
echo "$R" | grep -q "echo tick" && exit 1

# and it must still be a runnable entrypoint - the sh -c prefix repeated,
# which is the point of the step: an atomic list is replaced wholesale
echo "$R" | grep -A2 "^      - command:" | grep -q -- "- sh" || exit 1

# the app container's earlier merge must be untouched
echo "$R" | grep -q "name: KEEP_ME" || exit 1
COUNT=$(echo "$R" | grep -cE "^        name: ")
[ "$COUNT" == "2" ] || exit 1

exit 0
