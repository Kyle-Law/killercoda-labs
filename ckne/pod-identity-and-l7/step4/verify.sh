#!/bin/bash

# The step must end on the label-based rule, not the ipBlock one.
POL=$(kubectl get netpol api-l4 -o json 2>/dev/null) || exit 1
echo "$POL" | grep -q '"ipBlock"' && exit 1
echo "$POL" | grep -q '"app": *"web"' || exit 1

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || exit 1

# Traffic must flow again under the label selector.
for _ in $(seq 1 18); do
  OK=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  [ "$OK" == "200" ] && exit 0
  sleep 5
done

exit 1
