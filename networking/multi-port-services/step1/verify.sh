#!/bin/bash

TP=$(kubectl get svc api-svc -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
[ "$TP" == "http" ] || exit 1

for i in $(seq 1 3); do
  EP=$(kubectl get endpoints api-svc -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
  [ -n "$EP" ] || exit 1
  sleep 5
done

exit 0
