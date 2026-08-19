#!/bin/bash

for i in $(seq 1 3); do
  READY=$(kubectl get pods -n kube-system -l component=kube-scheduler -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] || exit 1
  sleep 5
done

exit 0
