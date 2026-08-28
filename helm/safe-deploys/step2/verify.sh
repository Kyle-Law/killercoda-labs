#!/bin/bash

# release must still exist - the failed upgrade should have rolled back, not
# destroyed it
helm status webserver >/dev/null 2>&1 || exit 1

for i in $(seq 1 18); do
  VALS=$(helm get values webserver 2>/dev/null)
  # podinfo's fullname template makes this "<release>-podinfo", not "<release>"
  READY=$(kubectl get deployment webserver-podinfo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if ! echo "$VALS" | grep -q "does-not-exist" && [ -n "$READY" ] && [ "$READY" -ge 1 ]; then
    exit 0
  fi
  sleep 5
done

exit 1
