#!/bin/bash

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$NODE" ] || exit 1

SCHED=$(kubectl get node "$NODE" -o jsonpath='{.spec.unschedulable}' 2>/dev/null)
[ "$SCHED" != "true" ] || exit 1

for i in $(seq 1 3); do
  RUNNING=$(kubectl get pods -l app=stuck-app --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$RUNNING" -ge 1 ] || exit 1
  sleep 5
done

exit 0
