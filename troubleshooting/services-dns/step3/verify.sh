#!/bin/bash

for i in $(seq 1 3); do
  kubectl exec test-client -- nslookup kubernetes.default >/dev/null 2>&1 || exit 1
  sleep 5
done

exit 0
