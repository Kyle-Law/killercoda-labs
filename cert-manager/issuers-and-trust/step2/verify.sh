#!/bin/bash
LOG=/root/.check
STEP="Step 2 · The namespace you never typed"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 18); do
  CIKIND=$(kubectl get clusterissuer lab-ca -o jsonpath='{.spec.ca.secretName}' 2>/dev/null)
  [ -n "$CIKIND" ] || { R="noissuer"; sleep 5; continue; }

  CIMSG=$(kubectl get clusterissuer lab-ca \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
  CIREADY=$(kubectl get clusterissuer lab-ca \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [ "$CIREADY" == "True" ] || { R="issuernotready"; sleep 5; continue; }

  REF=$(kubectl -n app get certificate web-cert -o jsonpath='{.spec.issuerRef.name}' 2>/dev/null)
  [ -n "$REF" ] || { R="nocert"; sleep 5; continue; }
  [ "$REF" == "lab-ca" ] || { R="wrongissuer"; sleep 5; continue; }

  DNS=$(kubectl -n app get certificate web-cert -o jsonpath='{.spec.dnsNames}' 2>/dev/null)
  echo "$DNS" | grep -q "web.app.svc.cluster.local" || { R="dnsnames"; sleep 5; continue; }

  CREADY=$(kubectl -n app get certificate web-cert \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [ "$CREADY" == "True" ] || { R="certnotready"; sleep 5; continue; }

  # Re-derive the issuer from the issued certificate itself rather than
  # trusting the issuerRef field -- a leaf signed by something else would
  # otherwise pass on the strength of a name.
  ISSUER=$(kubectl -n app get secret web-cert-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
    | base64 -d 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)
  echo "$ISSUER" | grep -q "lab-root-ca" || { R="notsignedbyca"; sleep 5; continue; }

  # A CA issuer publishes the chain; without ca.crt step 3 has nothing to
  # distribute and step 4 nothing to bundle.
  kubectl -n app get secret web-cert-tls -o jsonpath='{.data.ca\.crt}' 2>/dev/null \
    | grep -q . || { R="nocacrt"; sleep 5; continue; }

  pass
done

case "$R" in
  noissuer) fail \
    "There is no ClusterIssuer called 'lab-ca' with a spec.ca.secretName." \
    "" \
    "It has to be of type 'ca' -- backed by a keypair that already exists --" \
    "not selfSigned:" \
    "  kubectl get clusterissuer" \
    "  kubectl explain clusterissuer.spec.ca" ;;
  issuernotready) fail \
    "ClusterIssuer 'lab-ca' is not Ready (Ready=${CIREADY:-<none>})." \
    "" \
    "What it says:" \
    "  ${CIMSG:-<no message>}" \
    "" \
    "If that reads 'secrets ... not found', notice what it does NOT tell you: the" \
    "namespace it looked in. A ClusterIssuer has no namespace of its own, so it" \
    "cannot resolve a secretName against the caller's -- it uses one fixed" \
    "namespace for every Secret it ever reads:" \
    "  kubectl -n cert-manager get deploy cert-manager -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\\n'" ;;
  nocert) fail \
    "There is no Certificate called 'web-cert' in namespace app." \
    "" \
    "The ClusterIssuer being Ready only means its keypair loaded. Ask it for a" \
    "leaf certificate to prove it actually signs:" \
    "  kubectl -n app get certificate" ;;
  wrongissuer) fail \
    "'web-cert' is issued by '${REF}', not by 'lab-ca'." \
    "" \
    "  kubectl -n app get certificate web-cert -o jsonpath='{.spec.issuerRef}'" ;;
  dnsnames) fail \
    "'web-cert' does not ask for web.app.svc.cluster.local." \
    "" \
    "  dnsNames now: ${DNS:-<none>}" \
    "" \
    "That name is the web Service's own cluster DNS name, and step 3 needs a" \
    "certificate that matches it." ;;
  certnotready) fail \
    "'web-cert' is not Ready (Ready=${CREADY:-<none>})." \
    "" \
    "The ClusterIssuer loaded its keypair, so this is a problem with the request" \
    "rather than with the CA. Same place as step 1:" \
    "  kubectl -n app describe certificaterequest" ;;
  notsignedbyca) fail \
    "'web-cert' is Ready, but it was not signed by the lab CA." \
    "" \
    "  issuer on the actual certificate: ${ISSUER:-<could not read it>}" \
    "" \
    "The CA's commonName has to be lab-root-ca, and web-cert has to be issued by" \
    "the ClusterIssuer backed by it:" \
    "  kubectl -n app get secret web-cert-tls -o jsonpath='{.data.tls\\.crt}' | base64 -d | openssl x509 -noout -issuer -subject" ;;
  nocacrt) fail \
    "The Secret 'web-cert-tls' has no ca.crt key." \
    "" \
    "  kubectl -n app get secret web-cert-tls -o jsonpath='{.data}' | tr ',' '\\n'" \
    "" \
    "cert-manager writes the issuing certificate alongside the leaf, and steps 3" \
    "and 4 both need it. If it is absent the Secret was not written by" \
    "cert-manager at all." ;;
  *) fail "Unexpected state -- rerun the check." ;;
esac
