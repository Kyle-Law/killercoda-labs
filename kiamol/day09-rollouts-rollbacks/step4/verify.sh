#!/bin/bash

READY=""
for i in $(seq 1 12); do
  READY=$(kubectl get deployment web-green -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 5
done
[ "$READY" == "2" ] || exit 1

SELECTOR_VERSION=$(kubectl get svc web-bg -o jsonpath='{.spec.selector.version}' 2>/dev/null)
[ "$SELECTOR_VERSION" == "green" ] || exit 1

ENDPOINT_IPS=$(kubectl get endpoints web-bg -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
[ -n "$ENDPOINT_IPS" ] || exit 1

GREEN_IPS=$(kubectl get pod -l app=web-bg,version=green -o jsonpath='{.items[*].status.podIP}' 2>/dev/null)

SORTED_ENDPOINTS=$(echo "$ENDPOINT_IPS" | tr ' ' '\n' | sort)
SORTED_GREEN=$(echo "$GREEN_IPS" | tr ' ' '\n' | sort)
[ "$SORTED_ENDPOINTS" == "$SORTED_GREEN" ] || exit 1

# blue must still exist and still be healthy - deleting it would defeat
# the entire point of the pattern
BLUE_READY=$(kubectl get deployment web-blue -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$BLUE_READY" == "2" ]
