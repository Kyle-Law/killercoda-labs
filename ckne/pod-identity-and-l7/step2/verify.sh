#!/bin/bash

CNP=$(kubectl get ciliumnetworkpolicy api-l7 -o json 2>/dev/null) || exit 1
echo "$CNP" | grep -q '"http"' || exit 1

# The broad L4 allow must be gone. Left in place it unions with the L7 rule
# and permits everything on the port, which is the trap this step teaches.
kubectl get netpol api-l4 >/dev/null 2>&1 && exit 1

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || exit 1

# All three verdicts must hold at once: the allowed request succeeds, and the
# other two are REFUSED (403) rather than dropped (000) -- a 000 would mean an
# L3/L4 block, not L7 enforcement.
for _ in $(seq 1 18); do
  OK=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  BADPATH=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/ 2>/dev/null)
  BADMETHOD=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -X POST --data '' -w '%{http_code}' http://api/hostname 2>/dev/null)

  if [ "$OK" == "200" ] && [ "$BADPATH" == "403" ] && [ "$BADMETHOD" == "403" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
