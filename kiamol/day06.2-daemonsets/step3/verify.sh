#!/bin/bash

SELECTOR=$(kubectl get daemonset infra-agent -o jsonpath='{.spec.template.spec.nodeSelector.monitor}' 2>/dev/null)
[ "$SELECTOR" == "enabled" ] || exit 1

for i in $(seq 1 6); do
  DESIRED=$(kubectl get daemonset infra-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  READY=$(kubectl get daemonset infra-agent -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [ "$DESIRED" == "1" ] && [ "$READY" == "1" ] && exit 0
  sleep 5
done

exit 1
