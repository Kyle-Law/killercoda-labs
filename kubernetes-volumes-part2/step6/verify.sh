#!/bin/bash

# the Pod must never have restarted
RESTARTS=$(kubectl get pod config-pod -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
[ "$RESTARTS" == "0" ] || exit 1

for i in $(seq 1 12); do
  if kubectl exec config-pod -- cat /etc/config/app.properties 2>/dev/null | grep -q "color=red"; then
    exit 0
  fi
  sleep 5
done

exit 1
