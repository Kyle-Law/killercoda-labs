#!/bin/bash

SUSPEND=$(kubectl get cronjob backup-job -o jsonpath='{.spec.suspend}' 2>/dev/null)
[ "$SUSPEND" == "true" ] || exit 1

kubectl get job backup-manual-1 >/dev/null 2>&1 || exit 1

for i in $(seq 1 12); do
  SUCCEEDED=$(kubectl get job backup-manual-1 -o jsonpath='{.status.succeeded}' 2>/dev/null)
  [ "$SUCCEEDED" == "1" ] && exit 0
  sleep 5
done

exit 1
