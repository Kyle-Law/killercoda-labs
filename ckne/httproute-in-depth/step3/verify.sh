#!/bin/bash

for _ in $(seq 1 24); do
  W1=$(kubectl get httproute web-route -o jsonpath='{.spec.rules[0].backendRefs[?(@.name=="web")].weight}' 2>/dev/null)
  W2=$(kubectl get httproute web-route -o jsonpath='{.spec.rules[0].backendRefs[?(@.name=="web-canary")].weight}' 2>/dev/null)
  [ "$W1" == "80" ] && [ "$W2" == "20" ] || { sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { sleep 5; continue; }

  RESULTS=$(kubectl exec client -- /bin/sh -c "
    for i in \$(seq 1 200); do
      wget -qO- -T3 --header='Host: web.example.com' http://$GWIP/hostname
      echo
    done" 2>/dev/null)

  CANARY_COUNT=$(echo "$RESULTS" | grep -c '^web-canary-')
  TOTAL=$(echo "$RESULTS" | grep -c '^web-')

  # Generous tolerance around the 20% target -- this only needs to prove the
  # split is real and roughly in the right ballpark, not land on an exact
  # number, since 200 independent draws won't reproduce 20% precisely.
  if [ "$TOTAL" -ge 190 ] && [ "$CANARY_COUNT" -ge 10 ] && [ "$CANARY_COUNT" -le 45 ]; then
    exit 0
  fi
  sleep 5
done

exit 1
