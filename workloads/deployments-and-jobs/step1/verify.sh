#!/bin/bash

IMG=$(kubectl get deployment frontend -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$IMG" == "nginx:1.27-alpine" ] || exit 1

for i in $(seq 1 6); do
  READY=$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "3" ] || exit 1
  sleep 5
done

exit 0
