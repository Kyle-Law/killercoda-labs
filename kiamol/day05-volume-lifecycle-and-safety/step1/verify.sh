#!/bin/bash

RESTARTS=$(kubectl get pod data-pod -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
[ -n "$RESTARTS" ] && [ "$RESTARTS" -ge 1 ] || exit 1

# the file must be gone from the new container
if kubectl exec data-pod -- cat /data.txt >/dev/null 2>&1; then exit 1; fi

ANSWER=$(tr -d '[:space:]' < /root/lifecycle-confirmed.txt 2>/dev/null)
[ "$ANSWER" == "confirmed" ]
