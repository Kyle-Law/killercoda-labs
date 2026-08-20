#!/bin/bash

kubectl get pod legacy-app -o jsonpath='{.spec.containers[*].name}' | grep -qw logger || exit 1

for i in $(seq 1 8); do
  kubectl logs legacy-app -c logger 2>/dev/null | grep -q "." && exit 0
  sleep 5
done

exit 1
