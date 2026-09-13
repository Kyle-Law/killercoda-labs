#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · Two certificates, one port"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 30); do
  LISTENERS=$(kubectl get gateway web-gateway -o jsonpath='{.spec.listeners[*].name}' 2>/dev/null)
  echo "$LISTENERS" | grep -qw https-secure && echo "$LISTENERS" | grep -qw https-other || { R="names"; sleep 5; continue; }

  SEC_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="https-secure")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  OTH_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="https-other")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$SEC_PROG" == "True" ] && [ "$OTH_PROG" == "True" ] || { R="programmed"; sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { R="gwip"; sleep 5; continue; }

  # Independently re-derive which SAN each SNI name actually gets, rather than
  # trusting configuration alone -- the two certs must differ from each other.
  SECURE_SAN=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername secure.example.com 2>/dev/null \
    | openssl x509 -noout -ext subjectAltName 2>/dev/null)
  OTHER_SAN=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername other.example.com 2>/dev/null \
    | openssl x509 -noout -ext subjectAltName 2>/dev/null)
  echo "$SECURE_SAN" | grep -q "DNS:secure.example.com" || { R="securesan"; sleep 5; continue; }
  echo "$OTHER_SAN" | grep -q "DNS:other.example.com" || { R="othersan"; sleep 5; continue; }
  [ "$SECURE_SAN" != "$OTHER_SAN" ] || { R="samecert"; sleep 5; continue; }

  SECURE_ANS=$(curl -s --cacert /root/ca.crt --resolve "secure.example.com:443:$GWIP" "https://secure.example.com/hostname" 2>/dev/null)
  OTHER_ANS=$(curl -s --cacert /root/ca.crt --resolve "other.example.com:443:$GWIP" "https://other.example.com/hostname" 2>/dev/null)

  echo "$SECURE_ANS" | grep -q '^web-' && echo "$OTHER_ANS" | grep -q '^web-canary-' && pass
  R="routing"
  sleep 5
done

case "$R" in
  names) fail \
    "The Gateway does not have both listeners yet." \
    "" \
    "  listeners found: ${LISTENERS:-<none>}" \
    "  expected:        https-secure and https-other" \
    "" \
    "Two hostnames on one port means two listeners on that same port, each with" \
    "its own hostname and its own certificateRefs:" \
    "  kubectl get gateway web-gateway -o yaml" ;;
  programmed) fail \
    "Both listeners exist, but they are not both Programmed (https-secure=${SEC_PROG:-<none>}, https-other=${OTH_PROG:-<none>})." \
    "" \
    "Each needs its own Certificate to be Ready and its Secret to exist. The" \
    "reason is recorded per listener:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.status.listeners}' | tr '{' '\\n'" \
    "  kubectl get certificate" ;;
  gwip) fail \
    "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
    "" \
    "  kubectl -n envoy-gateway-system get pods,svc" ;;
  securesan|othersan) fail \
    "One of the two names is not being served its own certificate." \
    "" \
    "  SNI secure.example.com ->  ${SECURE_SAN:-<no certificate>}" \
    "  SNI other.example.com  ->  ${OTHER_SAN:-<no certificate>}" \
    "" \
    "Envoy picks the listener by the SNI name the client sent, so each listener's" \
    "hostname field has to match the name it is meant to answer for:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.spec.listeners}' | tr '{' '\\n'" ;;
  samecert) fail \
    "Both names are being served the same certificate." \
    "" \
    "$(echo "$SECURE_SAN" | sed 's/^/  /')" \
    "" \
    "That means one listener is answering for both SNI names -- usually a" \
    "hostname left off a listener, which makes it the catch-all. Selecting by SNI" \
    "is the whole point of the step:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.spec.listeners}' | tr '{' '\\n'" ;;
  *) fail \
    "Both certificates are served correctly, but the two names do not reach different backends." \
    "" \
    "  https://secure.example.com/hostname  ->  ${SECURE_ANS:-<nothing>}   (expected a web- Pod)" \
    "  https://other.example.com/hostname   ->  ${OTHER_ANS:-<nothing>}   (expected a web-canary- Pod)" \
    "" \
    "A route attaches to a named listener with sectionName, and its own hostnames" \
    "have to intersect the listener's:" \
    "  kubectl get httproute -o yaml | grep -A6 parentRefs" ;;
esac
