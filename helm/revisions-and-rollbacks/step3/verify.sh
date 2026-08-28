#!/bin/bash

# NOTE: the upstream version of this scenario had this check inverted -
# it ran 'if helm history | grep "Rollback to 2"; then exit 0; fi' inside a
# block whose stdout was redirected to a log file, so a *correct* rollback
# exited before printing the success marker and was graded as a failure,
# while doing nothing at all passed. Checked here the other way round.

# 'Rollback to N' is the description Helm writes for a rollback, so this
# distinguishes an actual rollback from manually re-upgrading to old values
helm history webserver 2>/dev/null | grep -q "Rollback to 2" || exit 1

# and the release must actually be healthy again
for i in $(seq 1 18); do
  VALS=$(helm get values webserver 2>/dev/null)
  # podinfo's fullname template makes this "<release>-podinfo", not "<release>"
  READY=$(kubectl get deployment webserver-podinfo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if ! echo "$VALS" | grep -q "does-not-exist" && [ -n "$READY" ] && [ "$READY" -ge 1 ]; then
    exit 0
  fi
  sleep 5
done

exit 1
