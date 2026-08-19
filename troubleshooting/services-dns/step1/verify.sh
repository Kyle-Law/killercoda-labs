#!/bin/bash

for i in $(seq 1 3); do
  EP=$(kubectl get endpoints backend-svc -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
  [ -n "$EP" ] || exit 1
  sleep 5
done

exit 0
