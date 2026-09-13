#!/bin/bash

POL=$(kubectl get netpol api-l4 -o json 2>/dev/null) || exit 1
echo "$POL" | grep -q '"app": *"api"' || exit 1
echo "$POL" | grep -q '"app": *"web"' || exit 1
echo "$POL" | grep -q '8080' || exit 1

# No L7 policy yet -- that is step 2. Passing this step with one already in
# place would skip the limit the step exists to demonstrate.
kubectl get ciliumnetworkpolicy api-l7 >/dev/null 2>&1 && exit 1

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || exit 1

# The L4 policy must genuinely allow the traffic -- including the POST it
# cannot distinguish, which is the whole point.
for _ in $(seq 1 12); do
  G=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  P=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -X POST --data '' -w '%{http_code}' http://api/ 2>/dev/null)
  [ "$G" == "200" ] && [ "$P" == "200" ] && exit 0
  sleep 5
done

exit 1
