#!/bin/bash

for i in $(seq 1 3); do
  READY=$(kubectl get pods -n kube-system -l component=kube-controller-manager -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] || exit 1
  sleep 5
done

# and the deployment actually got reconciled into a ReplicaSet
RS_COUNT=$(kubectl get rs -l app=web --no-headers 2>/dev/null | wc -l)
[ "$RS_COUNT" -ge 1 ]
