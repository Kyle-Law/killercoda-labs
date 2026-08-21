#!/bin/bash

kubectl get statefulset db -o jsonpath='{.spec.volumeClaimTemplates[*].metadata.name}' | grep -qw data || exit 1
kubectl get statefulset db -o jsonpath='{.spec.volumeClaimTemplates[*].metadata.name}' | grep -qw logs || exit 1

for i in $(seq 1 8); do
  READY=$(kubectl get statefulset db -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 5
done
[ "$READY" == "2" ] || exit 1

kubectl exec db-1 -- cat /data/marker.txt 2>/dev/null | grep -q "important-data"
