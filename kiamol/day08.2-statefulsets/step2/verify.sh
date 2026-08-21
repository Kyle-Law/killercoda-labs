#!/bin/bash

kubectl get pvc data-db-1 >/dev/null 2>&1 || exit 1

for i in $(seq 1 6); do
  READY=$(kubectl get statefulset db -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] || exit 1
  sleep 5
done

kubectl exec db-1 -- cat /data/marker.txt 2>/dev/null | grep -q "important-data"
