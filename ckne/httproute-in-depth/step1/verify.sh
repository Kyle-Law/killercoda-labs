#!/bin/bash

for _ in $(seq 1 24); do
  LISTENERS=$(kubectl get gateway web-gateway -o jsonpath='{.spec.listeners[*].name}' 2>/dev/null)
  echo "$LISTENERS" | grep -qw public && echo "$LISTENERS" | grep -qw internal || { sleep 5; continue; }

  PUBLIC_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="public")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  INTERNAL_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="internal")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$PUBLIC_PROG" == "True" ] && [ "$INTERNAL_PROG" == "True" ] || { sleep 5; continue; }

  # The route must be attached to the public listener specifically, not to
  # the Gateway as a whole -- sectionName is the point of this step.
  SECTION=$(kubectl get httproute web-route \
    -o jsonpath='{.spec.parentRefs[0].sectionName}' 2>/dev/null)
  [ "$SECTION" == "public" ] || { sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { sleep 5; continue; }

  PUBLIC_OK=$(kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname" 2>/dev/null)
  INTERNAL_CODE=$(kubectl exec client -- wget -S -O /dev/null -T5 --header="Host: web.example.com" "http://$GWIP:8080/hostname" 2>&1 \
    | grep -oE 'HTTP/[0-9.]+ [0-9]+' | awk '{print $2}' | head -1)

  # Reachable where attached, and specifically NOT reachable on the listener
  # it was never attached to -- a route that (wrongly) attached to both
  # listeners would pass the first check and fail this one.
  echo "$PUBLIC_OK" | grep -q "^web-" && [ "$INTERNAL_CODE" == "404" ] && exit 0
  sleep 5
done

exit 1
