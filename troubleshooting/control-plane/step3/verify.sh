#!/bin/bash

for i in $(seq 1 3); do
  kubectl get --raw /healthz --request-timeout=5s 2>/dev/null | grep -q "^ok$" || exit 1
  sleep 5
done

exit 0
