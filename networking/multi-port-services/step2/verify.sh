#!/bin/bash

PORTS=$(kubectl get svc multi-api-svc -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)
echo "$PORTS" | grep -qw 80 || exit 1
echo "$PORTS" | grep -qw 9113 || exit 1

NAMES=$(kubectl get svc multi-api-svc -o jsonpath='{.spec.ports[*].name}' 2>/dev/null)
NAME_COUNT=$(echo "$NAMES" | wc -w)
[ "$NAME_COUNT" -eq 2 ] || exit 1

for i in $(seq 1 3); do
  EP=$(kubectl get endpoints multi-api-svc -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
  [ -n "$EP" ] || exit 1
  sleep 5
done

exit 0
