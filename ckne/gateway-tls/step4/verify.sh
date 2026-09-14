#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · The key the platform never holds"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 30); do
  PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="tls-passthrough")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$PROG" == "True" ] || { R="listener"; sleep 5; continue; }

  MODE=$(kubectl get gateway web-gateway \
    -o jsonpath='{.spec.listeners[?(@.name=="tls-passthrough")].tls.mode}' 2>/dev/null)
  [ "$MODE" == "Passthrough" ] || { R="mode"; sleep 5; continue; }

  # A Passthrough listener must never carry certificateRefs -- Envoy holding
  # no key is the entire point being tested.
  CERTREF=$(kubectl get gateway web-gateway \
    -o jsonpath='{.spec.listeners[?(@.name=="tls-passthrough")].tls.certificateRefs}' 2>/dev/null)
  [ -z "$CERTREF" ] || fail \
    "The Passthrough listener still names a certificate." \
    "" \
    "  certificateRefs: $CERTREF" \
    "" \
    "Passthrough means the Gateway never decrypts anything, so it has no use for" \
    "a key -- and handing it one defeats the property the step is demonstrating." \
    "Remove certificateRefs from that listener entirely."

  RESOLVED=$(kubectl get tlsroute pass-route \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
  [ "$RESOLVED" == "True" ] || { R="route"; sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { R="gwip"; sleep 5; continue; }

  # The certificate on the wire has to be tls-backend's own, matching the
  # Secret mounted into that Pod directly -- proof the Gateway never
  # substituted anything of its own.
  SERVED_SERIAL=$(echo | timeout 5 openssl s_client -connect "$GWIP:8443" -servername pass.example.com 2>/dev/null \
    | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
  BACKEND_SERIAL=$(kubectl get secret pass-cert-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
    | base64 -d | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
  [ -n "$SERVED_SERIAL" ] && [ "$SERVED_SERIAL" == "$BACKEND_SERIAL" ] || { R="serial"; sleep 5; continue; }

  ANSWER=$(curl -sk --resolve "pass.example.com:8443:$GWIP" "https://pass.example.com:8443/" 2>/dev/null)
  [ "$ANSWER" == "tls-backend" ] && pass
  R="request"
  sleep 5
done

case "$R" in
  listener) fail \
    "The 'tls-passthrough' listener is not Programmed (Programmed=${PROG:-<none>})." \
    "" \
    "It needs protocol TLS on port 8443 with mode Passthrough. Read what the" \
    "listener itself objects to:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.status.listeners}' | tr '{' '\\n'" ;;
  mode) fail \
    "The listener's TLS mode is '${MODE:-<unset>}', not 'Passthrough'." \
    "" \
    "Terminate is the default, and it is the opposite of what this step is about:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.spec.listeners}' | tr '{' '\\n'" ;;
  route) fail \
    "The TLSRoute 'pass-route' has not resolved its references (ResolvedRefs=${RESOLVED:-<none>})." \
    "" \
    "A Passthrough listener's supportedKinds is TLSRoute only -- it refuses an" \
    "HTTPRoute outright rather than merely failing to route with it. Check what" \
    "kind the listener will accept, and what the route says about itself:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.status.listeners}' | tr '{' '\\n'" \
    "  kubectl get tlsroute pass-route -o yaml | tail -25" ;;
  gwip) fail \
    "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
    "" \
    "  kubectl -n envoy-gateway-system get pods,svc" ;;
  serial) fail \
    "The certificate arriving on :8443 is not the backend's own." \
    "" \
    "  serial on the wire:          ${SERVED_SERIAL:-<no certificate>}" \
    "  serial in pass-cert-tls:     ${BACKEND_SERIAL:-<none>}" \
    "" \
    "In Passthrough the bytes are forwarded untouched, so the certificate the" \
    "client sees must be the one mounted into the backend Pod. A different serial" \
    "means something is still terminating in the middle:" \
    "  kubectl get pod -l app=tls-backend -o yaml | grep -A5 volumeMounts" ;;
  *) fail \
    "Everything is wired up, but the request did not come back from the backend." \
    "" \
    "  response: ${ANSWER:-<nothing>}   (expected 'tls-backend')" \
    "" \
    "The TLSRoute matches on SNI, so the client has to send the name the route" \
    "expects -- and the backend has to be listening with TLS itself, since" \
    "nothing else is going to do it for it:" \
    "  kubectl get tlsroute pass-route -o yaml" \
    "  kubectl get pods -l app=tls-backend" ;;
esac
