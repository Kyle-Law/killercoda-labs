#!/bin/bash

for i in $(seq 1 3); do
  READY=$(kubectl get pod probe-pod -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] || exit 1
  sleep 5
done

exit 0
