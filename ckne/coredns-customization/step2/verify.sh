#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · A zone this cluster doesn't own"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The zone has to resolve through cluster DNS -- asking the corporate resolver
# directly would have worked before the change and proves nothing.
for _ in $(seq 1 30); do
  DB=$(kubectl exec dnstools -- dig +short db.corp.internal 2>/dev/null | tr -d '[:space:]')

  if [ "$DB" == "10.99.0.42" ]; then
    # ...and the rest of DNS must still work. A forward in the wrong block
    # would resolve corp.internal and break everything else.
    WEB=$(kubectl exec dnstools -- dig +short web.default.svc.cluster.local 2>/dev/null | tr -d '[:space:]')
    CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    [ -n "$WEB" ] && [ "$WEB" == "$CLUSTER_IP" ] && pass
  fi
  sleep 5
done

CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ "$DB" != "10.99.0.42" ]; then
  fail \
    "db.corp.internal does not resolve through cluster DNS." \
    "" \
    "  dig +short db.corp.internal  ->  ${DB:-<nothing>}" \
    "  expected                     ->  10.99.0.42" \
    "" \
    "The zone has to be its own server block in the Corefile, forwarding to the" \
    "corporate resolver -- not a forward added inside the cluster.local block." \
    "Check what is in force and what CoreDNS made of it:" \
    "  kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'" \
    "  kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20" \
    "" \
    "Changes take up to a minute to reach the Pod before reload sees them."
fi

fail \
  "db.corp.internal resolves, but ordinary cluster DNS has stopped working." \
  "" \
  "  web.default.svc.cluster.local  ->  ${WEB:-<nothing>}" \
  "  the web Service's ClusterIP    ->  ${CLUSTER_IP:-<none>}" \
  "" \
  "That is what a forward in the wrong block does: it catches everything, so" \
  "corp.internal resolves and every Service name goes to the corporate resolver" \
  "as well. Give the zone its own block:" \
  "  kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'"
