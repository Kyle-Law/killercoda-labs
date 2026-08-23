#!/bin/bash

STRATEGY1=$(kubectl get deployment stateful-cache -o jsonpath='{.spec.strategy.type}' 2>/dev/null)
[ "$STRATEGY1" == "Recreate" ] || exit 1

MAXUNAVAIL=$(kubectl get deployment always-on -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)
[ "$MAXUNAVAIL" == "0" ] || exit 1

for i in $(seq 1 12); do
  IMG=$(kubectl get deployment always-on -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  READY=$(kubectl get deployment always-on -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$IMG" == "nginx:1.26-alpine" ] && [ "$READY" == "4" ] && exit 0
  sleep 5
done

exit 1
