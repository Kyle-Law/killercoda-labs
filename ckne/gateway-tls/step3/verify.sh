#!/bin/bash

GWIP=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
  -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
[ -n "$GWIP" ] || exit 1

# step1 recorded the certificate's original serial the moment it first went
# live. Without that, a fresh-from-step-1 certificate and a genuinely
# renewed one are indistinguishable -- both are "recent" by any time-based
# check, since step 1 only just finished.
[ -f /root/.secure-cert-original-serial ] || exit 1
ORIGINAL_SERIAL=$(cat /root/.secure-cert-original-serial)
CURRENT_SERIAL=$(kubectl get secret secure-cert-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
  | base64 -d | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
[ -n "$CURRENT_SERIAL" ] && [ "$CURRENT_SERIAL" != "$ORIGINAL_SERIAL" ] || exit 1

# No object anywhere in the Gateway/Envoy chain should have needed touching.
ENVOY_RESTARTS=$(kubectl -n envoy-gateway-system get pods -l gateway.envoyproxy.io/owning-gateway-name=web-gateway \
  -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
[ "$ENVOY_RESTARTS" == "0" ] || exit 1

for _ in $(seq 1 20); do
  SERVED_SERIAL=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername secure.example.com 2>/dev/null \
    | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
  SECRET_SERIAL=$(kubectl get secret secure-cert-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
    | base64 -d | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)

  # What Envoy actually hands out on the wire has to match what's in the
  # Secret right now -- proof the new keypair, not a cached old one, is live.
  [ -n "$SERVED_SERIAL" ] && [ "$SERVED_SERIAL" == "$SECRET_SERIAL" ] && exit 0
  sleep 5
done

exit 1
