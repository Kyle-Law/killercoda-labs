#!/bin/bash

kubectl get prometheus main >/dev/null 2>&1 || exit 1

SA=$(kubectl get prometheus main -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[ "$SA" == "prometheus" ] || exit 1

# the operator should reconcile the CR into a StatefulSet it names itself
for i in $(seq 1 40); do
  READY=$(kubectl get statefulset prometheus-main -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" -ge 1 ] 2>/dev/null && exit 0
  sleep 10
done

exit 1
