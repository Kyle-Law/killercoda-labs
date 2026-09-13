#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
# The loop records the condition it is still waiting on in R, and if it runs
# out of attempts that is what the learner is told.
LOG=/root/.check
STEP="Step 1 · A certificate, a listener, a real handshake"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 30); do
  READY=$(kubectl get certificate secure-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [ "$READY" == "True" ] || { R="cert"; sleep 5; continue; }

  PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="https")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$PROG" == "True" ] || { R="listener"; sleep 5; continue; }

  # The listener has to be referencing THIS Secret, not just any TLS Secret --
  # otherwise a listener pointed at an unrelated cert would still pass.
  SECRET_REF=$(kubectl get gateway web-gateway \
    -o jsonpath='{.spec.listeners[?(@.name=="https")].tls.certificateRefs[0].name}' 2>/dev/null)
  [ "$SECRET_REF" == "secure-cert-tls" ] || { R="secretref"; sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { R="gwip"; sleep 5; continue; }

  # Independently re-derive the served cert's SAN and issuer, rather than
  # trusting anything the learner's own helper reported.
  SERVED=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername secure.example.com 2>/dev/null \
    | openssl x509 -noout -issuer -ext subjectAltName -serial 2>/dev/null)
  echo "$SERVED" | grep -q "CN=lab-root-ca" || { R="issuer"; sleep 5; continue; }
  echo "$SERVED" | grep -q "DNS:secure.example.com" || { R="san"; sleep 5; continue; }

  ANSWER=$(curl -s --cacert /root/ca.crt --resolve "secure.example.com:443:$GWIP" \
    "https://secure.example.com/hostname" 2>/dev/null)
  WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  if [ -n "$ANSWER" ] && [ "$ANSWER" == "$WEBPOD" ]; then
    # Recorded once, for step 3 to prove a later reissuance actually changed
    # something -- a "was it renewed" check has nothing to compare against
    # without knowing what the certificate looked like to begin with.
    echo "$SERVED" | grep -oE 'serial=.*' | cut -d= -f2 > /root/.secure-cert-original-serial
    pass
  fi
  R="request"
  sleep 5
done

case "$R" in
  cert) fail \
    "The Certificate 'secure-cert' is not Ready (Ready=${READY:-<none>})." \
    "" \
    "cert-manager reports what it is waiting on in the Certificate's own events --" \
    "usually a missing Issuer, or an issuerRef naming the wrong kind:" \
    "  kubectl describe certificate secure-cert | tail -20" \
    "  kubectl get issuer,clusterissuer" ;;
  listener) fail \
    "The 'https' listener on 'web-gateway' is not Programmed (Programmed=${PROG:-<none>})." \
    "" \
    "A TLS listener stays unprogrammed until its Secret exists and is readable." \
    "The reason is on the listener, not the Gateway:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.status.listeners}' | tr '{' '\\n'" ;;
  secretref) fail \
    "The 'https' listener points at '${SECRET_REF:-<nothing>}', not 'secure-cert-tls'." \
    "" \
    "certificateRefs names the Secret cert-manager writes, which is the" \
    "secretName from the Certificate -- not the Certificate's own name:" \
    "  kubectl get certificate secure-cert -o jsonpath='{.spec.secretName}'" ;;
  gwip) fail \
    "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
    "" \
    "  kubectl -n envoy-gateway-system get pods,svc" \
    "" \
    "(An EXTERNAL-IP of <pending> is expected here -- the lab uses the ClusterIP.)" ;;
  issuer) fail \
    "The certificate served on :443 was not issued by the lab CA." \
    "" \
    "What is actually on the wire:" \
    "$(echo "$SERVED" | sed 's/^/  /')" \
    "" \
    "Envoy serves a self-signed placeholder when it has no usable certificate for" \
    "a listener, which looks like a working handshake until you read the issuer." ;;
  san) fail \
    "The served certificate does not carry secure.example.com as a SAN." \
    "" \
    "What is actually on the wire:" \
    "$(echo "$SERVED" | sed 's/^/  /')" \
    "" \
    "Modern clients ignore CN entirely and match only against subjectAltName, so" \
    "dnsNames on the Certificate is the field that matters:" \
    "  kubectl get certificate secure-cert -o jsonpath='{.spec.dnsNames}'" ;;
  *) fail \
    "The handshake works, but the request did not come back from the web Pod." \
    "" \
    "  response:      ${ANSWER:-<nothing>}" \
    "  expected Pod:  ${WEBPOD:-<none>}" \
    "" \
    "TLS terminating is only half of it -- an HTTPRoute still has to attach to the" \
    "https listener and send the traffic to the web Service:" \
    "  kubectl get httproute -o wide" \
    "  kubectl get pods -l app=web" ;;
esac
