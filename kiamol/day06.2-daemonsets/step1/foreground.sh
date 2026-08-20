#!/bin/bash

while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY_COUNT=$(kubectl get nodes -o jsonpath="{range .items[*]}{.status.conditions[?(@.type=='Ready')].status}{'\n'}{end}" 2>/dev/null | grep -c "^True$")
  [ "$READY_COUNT" -ge 2 ] && break
  sleep 3
done

echo "Ready. Good luck!"
