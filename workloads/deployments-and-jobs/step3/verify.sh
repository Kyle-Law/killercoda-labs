#!/bin/bash

for i in $(seq 1 24); do
  LAST=$(kubectl get cronjob log-cleanup -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null)
  [ -n "$LAST" ] && exit 0
  sleep 5
done

exit 1
