#!/bin/bash

kubectl get deployment shop >/dev/null 2>&1 || exit 1

# The flapping release must be what's deployed...
CMD=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$CMD" | grep -q "readyz/disable" || exit 1

# ...and it must have had a working readiness probe all along -- the point of
# the step is that a correct readiness probe was not sufficient here.
PROBE=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
[ -n "$PROBE" ] || exit 1

# The rollout must have gone all the way through, replacing every old Pod...
for i in $(seq 1 30); do
  UPDATED=$(kubectl get deployment shop -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
  [ -z "$UPDATED" ] && UPDATED=0
  AVAIL=$(kubectl get deployment shop -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  [ -z "$AVAIL" ] && AVAIL=0

  # ...and then collapsed, leaving nothing serving.
  if [ "$UPDATED" == "4" ] && [ "$AVAIL" -le 1 ]; then
    exit 0
  fi
  sleep 5
done

exit 1
