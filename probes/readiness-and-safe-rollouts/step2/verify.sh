#!/bin/bash

kubectl get deployment shop >/dev/null 2>&1 || exit 1

# A readiness probe must now be in place...
PROBE=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
[ -n "$PROBE" ] || exit 1

# ...and the broken release must have been attempted on top of it.
CMD=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$CMD" | grep -q "sleep 3600" || exit 1

for i in $(seq 1 24); do
  # The rollout must be contained, not complete: some old Pods still serving.
  UPDATED=$(kubectl get deployment shop -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
  [ -z "$UPDATED" ] && UPDATED=0
  AVAIL=$(kubectl get deployment shop -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  [ -z "$AVAIL" ] && AVAIL=0

  if [ "$UPDATED" -lt 4 ] && [ "$AVAIL" -ge 2 ]; then
    # And users must still be getting served throughout.
    CODE=$(curl -s -m 2 -o /dev/null -w '%{http_code}' http://localhost:30080/ 2>/dev/null)
    [ "$CODE" == "200" ] && exit 0
  fi
  sleep 5
done

exit 1
