#!/bin/bash

for _ in $(seq 1 24); do
  RULE_COUNT=$(kubectl get httproute web-route -o jsonpath='{.spec.rules[*]}' 2>/dev/null | grep -o '"backendRefs"' | wc -l)
  [ "$RULE_COUNT" -ge 2 ] || { sleep 5; continue; }

  # The final state this step leaves things in is the header-based rule
  # (the second half of the solution) -- both a header condition and a
  # PathPrefix condition present somewhere in the route.
  kubectl get httproute web-route -o json 2>/dev/null | grep -q '"headers"' || { sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { sleep 5; continue; }

  NO_HEADER=$(kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname" 2>/dev/null)
  WITH_HEADER=$(kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" --header="x-canary: true" "http://$GWIP:80/hostname" 2>/dev/null)

  # Precedence has to actually be observable, not just configured: the
  # unmatched request goes to web, the header-matched one goes to web-canary,
  # and they must differ from each other.
  echo "$NO_HEADER" | grep -q '^web-' || { sleep 5; continue; }
  echo "$WITH_HEADER" | grep -q '^web-canary-' || { sleep 5; continue; }
  [ "$NO_HEADER" != "$WITH_HEADER" ] && exit 0
  sleep 5
done

exit 1
