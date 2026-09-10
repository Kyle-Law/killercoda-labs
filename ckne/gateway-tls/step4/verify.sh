#!/bin/bash

for _ in $(seq 1 30); do
  PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="tls-passthrough")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$PROG" == "True" ] || { sleep 5; continue; }

  MODE=$(kubectl get gateway web-gateway \
    -o jsonpath='{.spec.listeners[?(@.name=="tls-passthrough")].tls.mode}' 2>/dev/null)
  [ "$MODE" == "Passthrough" ] || { sleep 5; continue; }

  # A Passthrough listener must never carry certificateRefs -- Envoy holding
  # no key is the entire point being tested.
  CERTREF=$(kubectl get gateway web-gateway \
    -o jsonpath='{.spec.listeners[?(@.name=="tls-passthrough")].tls.certificateRefs}' 2>/dev/null)
  [ -z "$CERTREF" ] || exit 1

  RESOLVED=$(kubectl get tlsroute pass-route \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
  [ "$RESOLVED" == "True" ] || { sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { sleep 5; continue; }

  # The certificate on the wire has to be tls-backend's own, matching the
  # Secret mounted into that Pod directly -- proof the Gateway never
  # substituted anything of its own.
  SERVED_SERIAL=$(echo | timeout 5 openssl s_client -connect "$GWIP:8443" -servername pass.example.com 2>/dev/null \
    | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
  BACKEND_SERIAL=$(kubectl get secret pass-cert-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
    | base64 -d | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
  [ -n "$SERVED_SERIAL" ] && [ "$SERVED_SERIAL" == "$BACKEND_SERIAL" ] || { sleep 5; continue; }

  ANSWER=$(curl -sk --resolve "pass.example.com:8443:$GWIP" "https://pass.example.com:8443/" 2>/dev/null)
  [ "$ANSWER" == "tls-backend" ] && exit 0
  sleep 5
done

exit 1
