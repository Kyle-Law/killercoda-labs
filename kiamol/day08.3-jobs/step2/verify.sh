#!/bin/bash

COMPLETIONS=$(kubectl get job batch-job -o jsonpath='{.spec.completions}' 2>/dev/null)
[ "$COMPLETIONS" == "5" ] || exit 1

PARALLELISM=$(kubectl get job batch-job -o jsonpath='{.spec.parallelism}' 2>/dev/null)
[ "$PARALLELISM" == "2" ] || exit 1

for i in $(seq 1 20); do
  SUCCEEDED=$(kubectl get job batch-job -o jsonpath='{.status.succeeded}' 2>/dev/null)
  [ "$SUCCEEDED" == "5" ] && exit 0
  sleep 5
done

exit 1
