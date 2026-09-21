#!/bin/bash
LOG=/root/.check
STEP="Step 3 · Ready is not the same as trusted"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""
ANSWER=/root/answers/ca.crt

for _ in $(seq 1 12); do
  AVAIL=$(kubectl -n app get deploy web \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  [ "${AVAIL:-0}" -ge 1 ] 2>/dev/null || { R="noweb"; sleep 5; continue; }

  IP=$(kubectl -n app get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  [ -n "$IP" ] || { R="nosvc"; sleep 5; continue; }

  SERVED=$(echo | timeout 5 openssl s_client -connect "$IP:8443" \
    -servername web.app.svc.cluster.local 2>/dev/null \
    | openssl x509 -noout -issuer -ext subjectAltName 2>/dev/null)
  echo "$SERVED" | grep -q "lab-root-ca" || { R="wrongserved"; sleep 5; continue; }
  echo "$SERVED" | grep -q "DNS:web.app.svc.cluster.local" || { R="wrongsan"; sleep 5; continue; }

  [ -s "$ANSWER" ] || { R="noanswer"; sleep 5; continue; }

  # A private key in a file destined for a trust store is the one mistake here
  # with real consequences, so it is refused outright rather than passed over.
  grep -q "PRIVATE KEY" "$ANSWER" && { R="haskey"; break; }

  SUBJ=$(openssl x509 -in "$ANSWER" -noout -subject 2>/dev/null)
  [ -n "$SUBJ" ] || { R="notacert"; sleep 5; continue; }

  # tls.crt also makes curl succeed -- OpenSSL will anchor on the leaf itself --
  # so the check has to look at what the file IS, not at whether it works.
  BC=$(openssl x509 -in "$ANSWER" -noout -ext basicConstraints 2>/dev/null)
  echo "$BC" | grep -q "CA:TRUE" || { R="nottheca"; sleep 5; continue; }
  echo "$SUBJ" | grep -q "lab-root-ca" || { R="wrongca"; sleep 5; continue; }

  BODY=$(curl -s --cacert "$ANSWER" --resolve "web.app.svc.cluster.local:8443:$IP" \
    https://web.app.svc.cluster.local:8443/ 2>/dev/null)
  echo "$BODY" | grep -q "web, in namespace app" || { R="curlfail"; sleep 5; continue; }

  pass
done

case "$R" in
  noweb) fail \
    "The web Deployment in namespace app has no available replicas." \
    "" \
    "  kubectl apply -f /root/web.yaml" \
    "  kubectl -n app get pods -l app=web" \
    "" \
    "A Pod stuck in ContainerCreating usually means the Secret it mounts does not" \
    "exist -- web.yaml mounts web-cert-tls, which step 2 produces." ;;
  nosvc) fail \
    "The web Service in namespace app has no ClusterIP." \
    "" \
    "  kubectl -n app get svc web" ;;
  wrongserved) fail \
    "The certificate served on :8443 was not issued by the lab CA." \
    "" \
    "What is actually on the wire:" \
    "$(echo "${SERVED:-<no handshake>}" | sed 's/^/  /')" \
    "" \
    "  servedcert" \
    "" \
    "If nginx started before web-cert-tls existed it is serving something else --" \
    "  kubectl -n app rollout restart deploy/web" ;;
  wrongsan) fail \
    "The served certificate does not carry web.app.svc.cluster.local as a SAN." \
    "" \
    "$(echo "${SERVED:-<no handshake>}" | sed 's/^/  /')" \
    "" \
    "Clients match on subjectAltName and ignore the common name entirely." ;;
  noanswer) fail \
    "/root/answers/ca.crt does not exist, or is empty." \
    "" \
    "The task is to write the certificate that makes the client trust this server" \
    "to that path. cert-manager already put it next to the leaf:" \
    "  kubectl -n app get secret web-cert-tls -o jsonpath='{.data}' | tr ',' '\\n'" ;;
  haskey) fail \
    "/root/answers/ca.crt contains a PRIVATE KEY." \
    "" \
    "This file is a trust store -- it is meant to be copied to every client that" \
    "has to verify this CA. A key in it is the one mistake in this lab that would" \
    "actually matter: anyone holding it can issue certificates the whole cluster" \
    "trusts." \
    "" \
    "Extract only the certificate, not the whole Secret." ;;
  notacert) fail \
    "/root/answers/ca.crt is not a PEM certificate openssl can read." \
    "" \
    "  openssl x509 -in /root/answers/ca.crt -noout -subject" \
    "" \
    "The value in the Secret is base64 on top of PEM, so it needs decoding first:" \
    "  ... -o jsonpath='{.data.ca\\.crt}' | base64 -d" ;;
  nottheca) fail \
    "/root/answers/ca.crt is a certificate, but it is not a CA." \
    "" \
    "  ${SUBJ:-<no subject>}" \
    "  ${BC:-<no basicConstraints>}" \
    "" \
    "This is almost certainly tls.crt, the leaf. Handing a client the leaf DOES" \
    "make curl succeed -- OpenSSL will anchor on the exact certificate presented --" \
    "which is why this is a trap rather than an alternative. It trusts one" \
    "certificate that expires in 90 days, instead of the authority that issues" \
    "them, and step 4 has nothing to distribute." ;;
  wrongca) fail \
    "/root/answers/ca.crt is a CA, but not this cluster's lab-root-ca." \
    "" \
    "  ${SUBJ:-<no subject>}" ;;
  curlfail) fail \
    "The CA looks right, but a request verified against it did not come back." \
    "" \
    "  response: ${BODY:-<nothing>}" \
    "" \
    "  webcurl /root/answers/ca.crt" \
    "  kubectl -n app get pods -l app=web" ;;
  *) fail "Unexpected state -- rerun the check." ;;
esac
