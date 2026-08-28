#!/bin/bash

# The deliberately-failing install must not have left a working release behind -
# that is the point of --rollback-on-failure. Helm removes the release entirely
# when a *first* install fails this way; accept either "gone" or "present but
# not deployed", so this doesn't hinge on that detail.
# Kept to grep so it needs no jq/python on the box.
if helm ls -a 2>/dev/null | grep -E "^webserver[[:space:]]" | grep -q "deployed"; then
  exit 1
fi

# and no Pods from it may still be running.
# podinfo's fullname template names these "<release>-podinfo".
for i in $(seq 1 12); do
  COUNT=$(kubectl get pods -l app.kubernetes.io/name=webserver-podinfo \
    --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$COUNT" == "0" ] && exit 0
  sleep 5
done

exit 1
