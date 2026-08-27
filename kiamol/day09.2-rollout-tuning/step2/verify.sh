#!/bin/bash

# the Service must still span both versions - "solving" this by pointing the
# selector at one version defeats the whole pattern
SEL_VERSION=$(kubectl get svc shop -o jsonpath='{.spec.selector.version}' 2>/dev/null)
[ -z "$SEL_VERSION" ] || exit 1

IMG2=$(kubectl get deployment shop-v2 -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$IMG2" == "nginx:1.26-alpine" ] || exit 1

for i in $(seq 1 16); do
  R1=$(kubectl get deployment shop-v1 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  R2=$(kubectl get deployment shop-v2 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  EP_COUNT=$(kubectl get endpoints shop -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w | tr -d '[:space:]')
  if [ "$R1" == "4" ] && [ "$R2" == "1" ] && [ "$EP_COUNT" == "5" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
