#!/bin/bash

for i in $(seq 1 3); do
  RUNNING=$(kubectl get pods -n quota-ns -l app=web --no-headers 2>/dev/null | grep -c "1/1.*Running")
  [ "$RUNNING" -ge 3 ] || exit 1
  sleep 5
done

exit 0
