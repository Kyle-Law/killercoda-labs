#!/bin/bash

kubectl get httproute cross-ns-route -o jsonpath='{.metadata.name}' >/dev/null 2>&1 || exit 1
kubectl -n team-b get httproute cross-ns-route >/dev/null 2>&1 && exit 1

REF=$(kubectl get httproute cross-ns-route -o jsonpath='{.spec.rules[0].backendRefs[0].namespace}' 2>/dev/null)
[ "$REF" == "team-b" ] || exit 1

kubectl -n team-b get referencegrant allow-default-httproutes >/dev/null 2>&1 || exit 1

for _ in $(seq 1 24); do
  RESOLVED=$(kubectl get httproute cross-ns-route \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
  [ "$RESOLVED" == "True" ] || { sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { sleep 5; continue; }

  ANSWER=$(kubectl exec client -- wget -qO- -T5 --header="Host: team-b.example.com" "http://$GWIP:80/hostname" 2>/dev/null)
  TEAMB_POD=$(kubectl -n team-b get pod -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  [ -n "$ANSWER" ] && [ "$ANSWER" == "$TEAMB_POD" ] && exit 0
  sleep 5
done

exit 1
