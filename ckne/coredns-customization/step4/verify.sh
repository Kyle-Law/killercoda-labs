#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · The plugin that answers for names you never gave it"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

COREFILE=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)
[ -n "$COREFILE" ] || fail \
  "Could not read the 'coredns' ConfigMap." \
  "" \
  "  kubectl -n kube-system get cm coredns -o yaml"

echo "$COREFILE" | grep -qE '^\s*hosts(\s|\{|$)' || fail \
  "The live Corefile has no 'hosts' block." \
  "" \
  "The address has to be served from inside CoreDNS rather than forwarded --" \
  "nothing upstream owns storage.internal, so forwarding it can only ever fail." \
  "" \
  "The running Corefile is:" \
  "$(echo "$COREFILE" | sed 's/^/  /' | head -24)"

echo "$COREFILE" | grep -q "10.99.0.60" || fail \
  "The hosts block does not contain the address 10.99.0.60." \
  "" \
  "Entries are written the way /etc/hosts writes them -- address first, then the" \
  "name:" \
  "  hosts {" \
  "      10.99.0.60 nas.storage.internal" \
  "      fallthrough" \
  "  }"

# The whole point of the step: without fallthrough the block is authoritative
# for everything it is asked, and the damage lands on names it never mentions.
#
# Scoped to the hosts block deliberately: the kubernetes plugin carries its own
# "fallthrough in-addr.arpa ip6.arpa", so a bare grep for the word is satisfied
# by a line that has nothing to do with this step.
HOSTSBLOCK=$(echo "$COREFILE" | awk '/^[[:space:]]*hosts([[:space:]]|\{|$)/{f=1} f{print} f&&/^[[:space:]]*}/{exit}')
echo "$HOSTSBLOCK" | grep -q "fallthrough" || fail \
  "The hosts block has no 'fallthrough'." \
  "" \
  "Check what that costs before adding it -- ask for a Service name and see what" \
  "comes back:" \
  "  dnsq web.default.svc.cluster.local" \
  "" \
  "A 'hosts' block with no fallthrough answers for every name it is asked about," \
  "not just the ones you listed -- anything absent fails there instead of being" \
  "passed to the next plugin. And 'hosts' runs before 'kubernetes' in CoreDNS's" \
  "compiled plugin order, so it sees Service lookups first." \
  "" \
  "Your hosts block, as applied:" \
  "$(echo "$HOSTSBLOCK" | sed 's/^/  /')"

CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$CLUSTER_IP" ] || fail \
  "The 'web' Service is gone, so the earlier answers cannot be re-checked." \
  "" \
  "  kubectl get svc"

for _ in $(seq 1 30); do
  NAS=$(kubectl exec dnstools -- dig +short nas.storage.internal 2>/dev/null | tr -d '[:space:]')
  WEB=$(kubectl exec dnstools -- dig +short web.default.svc.cluster.local 2>/dev/null | tr -d '[:space:]')
  DB=$(kubectl exec dnstools -- dig +short db.corp.internal 2>/dev/null | tr -d '[:space:]')
  LEGACY=$(kubectl exec dnstools -- dig +short legacy-api.example.com 2>/dev/null | tr -d '[:space:]')

  if [ "$NAS" == "10.99.0.60" ] && [ "$WEB" == "$CLUSTER_IP" ] \
     && [ "$DB" == "10.99.0.42" ] && [ "$LEGACY" == "$CLUSTER_IP" ]; then
    pass
  fi
  sleep 5
done

fail \
  "The hosts block is in place, but not everything resolves the way it should." \
  "" \
  "  nas.storage.internal          ->  ${NAS:-<nothing>}   (expected 10.99.0.60)" \
  "  web.default.svc.cluster.local ->  ${WEB:-<nothing>}   (expected $CLUSTER_IP)" \
  "  db.corp.internal              ->  ${DB:-<nothing>}   (expected 10.99.0.42)" \
  "  legacy-api.example.com        ->  ${LEGACY:-<nothing>}   (expected $CLUSTER_IP)" \
  "" \
  "If only nas.storage.internal works, the hosts block is swallowing everything" \
  "else -- that is the fallthrough problem, and it is worth looking at before you" \
  "fix it." \
  "" \
  "If nas.storage.internal is the one failing, check the entry is inside the" \
  "'.:53' block and that CoreDNS reloaded:" \
  "  corefile" \
  "  corednsstatus" \
  "" \
  "The stub zone from step 2 and the rewrite from step 3 both have to survive" \
  "this step."
