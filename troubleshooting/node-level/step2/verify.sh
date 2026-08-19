#!/bin/bash

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$NODE" ] || exit 1

for i in $(seq 1 3); do
  STATUS=$(kubectl get node "$NODE" -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}" 2>/dev/null)
  [ "$STATUS" == "True" ] || exit 1
  sleep 5
done

exit 0
