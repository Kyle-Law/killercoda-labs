#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`. The loop records which
# condition it is still waiting on in R, and that is what gets reported if the
# attempts run out.
LOG=/root/.check
STEP="Step 1 · A reference that resolves to nothing"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 12); do
  DNS=$(kubectl -n app get certificate app-cert -o jsonpath='{.spec.dnsNames}' 2>/dev/null)
  [ -n "$DNS" ] || { R="gone"; sleep 5; continue; }

  # Guard against "fixing" it by rewriting it into a different certificate.
  echo "$DNS" | grep -q "app.example.internal" || { R="dnsnames"; sleep 5; continue; }

  READY=$(kubectl -n app get certificate app-cert \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [ "$READY" == "True" ] || { R="notready"; sleep 5; continue; }

  # Ready with no Secret would mean the status is stale, not that it worked.
  kubectl -n app get secret app-cert-tls >/dev/null 2>&1 || { R="nosecret"; sleep 5; continue; }

  pass
done

CRMSG=$(kubectl -n app get certificaterequest \
  -o jsonpath='{.items[-1:].status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)

case "$R" in
  gone) fail \
    "There is no Certificate called 'app-cert' in namespace app any more." \
    "" \
    "The task is to make the existing one issue, not to replace it:" \
    "  kubectl -n app get certificate" ;;
  dnsnames) fail \
    "'app-cert' no longer asks for app.example.internal." \
    "" \
    "  dnsNames now: ${DNS:-<none>}" \
    "" \
    "Issuing some other certificate is not the same as fixing this one -- what is" \
    "wrong here is the issuerRef, not the name being requested." ;;
  notready) fail \
    "'app-cert' is still not Ready (Ready=${READY:-<none>})." \
    "" \
    "The Certificate's own status will not tell you why -- it only ever says it is" \
    "issuing. The attempt lives on a separate object, one per issuance:" \
    "  kubectl -n app describe certificaterequest" \
    "" \
    "What the latest CertificateRequest currently reports:" \
    "  ${CRMSG:-<no CertificateRequest found>}" \
    "" \
    "Then compare that against what actually exists, and where:" \
    "  kubectl get issuer,clusterissuer -A" ;;
  nosecret) fail \
    "'app-cert' reports Ready, but the Secret 'app-cert-tls' does not exist." \
    "" \
    "  kubectl -n app get secret" \
    "" \
    "Give it a few seconds and press CHECK again. If it persists, the Secret was" \
    "deleted after issuance and cert-manager has not caught up yet." ;;
  *) fail "Unexpected state -- rerun the check." ;;
esac
