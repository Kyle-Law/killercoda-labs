#!/bin/bash

# The L7 policy must be back in place at the end of the step.
kubectl get ciliumnetworkpolicy api-l7 >/dev/null 2>&1 || exit 1

# And the proxy redirect it implies must actually be programmed -- that is the
# observation this step is about, not merely that the policy object exists.
for _ in $(seq 1 18); do
  STATUS=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    cilium-dbg status --verbose 2>/dev/null)
  echo "$STATUS" | grep -q 'cilium-http-ingress' || { sleep 5; continue; }

  WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -n "$WEBPOD" ] || { sleep 5; continue; }

  OK=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  [ "$OK" == "200" ] && exit 0
  sleep 5
done

exit 1
