#!/bin/bash

for i in $(seq 1 12); do
  IMG=$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  READY=$(kubectl get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$IMG" == "nginx:1.26-alpine" ] && [ "$READY" == "2" ] && exit 0
  sleep 5
done

exit 1
