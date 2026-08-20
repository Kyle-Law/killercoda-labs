#!/bin/bash

STRATEGY=$(kubectl get daemonset infra-agent -o jsonpath='{.spec.updateStrategy.type}' 2>/dev/null)
[ "$STRATEGY" == "OnDelete" ] || exit 1

SPEC_IMG=$(kubectl get daemonset infra-agent -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$SPEC_IMG" == "busybox:1.36" ] || exit 1

for i in $(seq 1 6); do
  POD_NAME=$(kubectl get pod -l app=infra-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD_NAME" ]; then
    POD_IMG=$(kubectl get pod "$POD_NAME" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
    [ "$POD_IMG" == "busybox:1.36" ] && exit 0
  fi
  sleep 5
done

exit 1
