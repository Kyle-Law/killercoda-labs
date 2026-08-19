#!/bin/bash

for i in $(seq 1 3); do
  kubectl exec test-client -- wget -qO- --timeout=3 web2-svc >/dev/null 2>&1 || exit 1
  sleep 5
done

exit 0
