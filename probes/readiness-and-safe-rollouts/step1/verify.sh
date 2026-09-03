#!/bin/bash

kubectl get deployment shop >/dev/null 2>&1 || exit 1

# The broken release must actually be rolled out...
CMD=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$CMD" | grep -q "sleep 3600" || exit 1

# ...still with no readiness probe, which is the whole point of the step.
PROBE=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
[ -z "$PROBE" ] || exit 1

# Kubernetes must be reporting full health for a Deployment that serves nothing.
for i in $(seq 1 24); do
  AVAIL=$(kubectl get deployment shop -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  UPDATED=$(kubectl get deployment shop -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
  if [ "$AVAIL" == "4" ] && [ "$UPDATED" == "4" ]; then
    # ...and the Service must genuinely be serving nothing.
    CODE=$(curl -s -m 2 -o /dev/null -w '%{http_code}' http://localhost:30080/ 2>/dev/null)
    [ "$CODE" == "000" ] && exit 0
  fi
  sleep 5
done

exit 1
