#!/bin/bash

kubectl create deployment history-app --image=busybox --replicas=1 -- sh -c "sleep 3600"
kubectl rollout status deployment/history-app --timeout=120s

# four more template changes = five revisions / five ReplicaSets in total.
# env changes rather than image changes, so no extra image pulls are needed
for i in 1 2 3 4; do
  kubectl set env deployment/history-app REV="$i"
  kubectl rollout status deployment/history-app --timeout=120s
done

touch /tmp/step3-applied
