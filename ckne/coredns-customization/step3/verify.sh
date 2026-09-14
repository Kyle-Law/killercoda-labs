#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · A name that isn't a Service"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$CLUSTER_IP" ] || fail \
  "The 'web' Service is gone, so there is nothing for the name to point at." \
  "" \
  "  kubectl get svc"

for _ in $(seq 1 30); do
  LEGACY=$(kubectl exec dnstools -- dig +short legacy-api.example.com 2>/dev/null | tr -d '[:space:]')

  if [ "$LEGACY" == "$CLUSTER_IP" ]; then
    # The rewrite must not have cost anything that already worked.
    WEB=$(kubectl exec dnstools -- dig +short web.default.svc.cluster.local 2>/dev/null | tr -d '[:space:]')
    DB=$(kubectl exec dnstools -- dig +short db.corp.internal 2>/dev/null | tr -d '[:space:]')
    [ "$WEB" == "$CLUSTER_IP" ] && [ "$DB" == "10.99.0.42" ] && pass
  fi
  sleep 5
done

if [ "$LEGACY" != "$CLUSTER_IP" ]; then
  fail \
    "legacy-api.example.com does not resolve to the web Service." \
    "" \
    "  dig +short legacy-api.example.com  ->  ${LEGACY:-<nothing>}" \
    "  web's ClusterIP                    ->  $CLUSTER_IP" \
    "" \
    "This name is not a Service, so nothing in the cluster will ever answer for" \
    "it by itself -- the query has to be rewritten into one that is. Plugin order" \
    "matters as much as the rule: a rewrite has to happen before the plugin that" \
    "would otherwise answer." \
    "  kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'" \
    "  kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20"
fi

fail \
  "The rewrite works, but something that used to work no longer does." \
  "" \
  "  web.default.svc.cluster.local  ->  ${WEB:-<nothing>}   (expected $CLUSTER_IP)" \
  "  db.corp.internal               ->  ${DB:-<nothing>}   (expected 10.99.0.42)" \
  "" \
  "A rewrite rule that is broader than intended will catch names it was never" \
  "meant to, and a rule placed above the wrong plugin can shadow a whole zone." \
  "Both earlier answers have to survive this step:" \
  "  kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'"
