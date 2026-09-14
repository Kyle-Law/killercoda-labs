#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · Break it, and notice what doesn't happen"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The stored config has to be valid again -- leaving the typo in place is the
# whole hazard this step is about, and DNS answering is not evidence that it
# is gone.
COREFILE=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)
echo "$COREFILE" | grep -q "forwardd" && fail \
  "The broken directive is still in the stored Corefile." \
  "" \
  "DNS answering is not evidence that it is gone -- the running Pods are serving" \
  "from the last config they could parse, and the next restart will pick up this" \
  "one and fail. Repair the ConfigMap:" \
  "  kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' | grep -n forwardd" \
  "  kubectl -n kube-system edit cm coredns"

echo "$COREFILE" | grep -qE '^\s*forward\s+\.' || fail \
  "The stored Corefile has no 'forward .' directive at all." \
  "" \
  "Repairing the typo means putting the original directive back, not deleting" \
  "the line -- without it nothing outside the cluster resolves:" \
  "  kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'"

CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$CLUSTER_IP" ] || fail \
  "The 'web' Service is gone, so the earlier answers cannot be re-checked." \
  "" \
  "  kubectl get svc"

# A healthy cluster with a valid Corefile is also the state this step *starts*
# in, so that alone would pass without the step being done. The evidence that
# it was done is a CoreDNS Pod that crashed on the broken config and recovered:
# restart counts it could not have had beforehand.
RESTARTED=$(kubectl -n kube-system get pods -l k8s-app=kube-dns \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[*].restartCount}{"\n"}{end}' 2>/dev/null \
  | awk '$1 > 0' | wc -l)
[ "$RESTARTED" -ge 1 ] || fail \
  "No CoreDNS Pod has ever restarted, so the break was never actually felt." \
  "" \
  "That is the point of the step: a Corefile CoreDNS cannot parse takes nothing" \
  "down until a Pod restarts, and until then the cluster looks perfectly healthy." \
  "Apply the broken config, watch DNS carry on working, then force a restart and" \
  "watch it fail:" \
  "  kubectl -n kube-system rollout restart deploy coredns" \
  "  kubectl -n kube-system get pods -l k8s-app=kube-dns -w"

for _ in $(seq 1 36); do
  # Every CoreDNS Pod must actually be able to start on the stored config.
  DESIRED=$(kubectl -n kube-system get deploy coredns -o jsonpath='{.spec.replicas}' 2>/dev/null)
  READY=$(kubectl -n kube-system get deploy coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  if [ -n "$DESIRED" ] && [ "$DESIRED" == "$READY" ]; then
    NOTRUNNING=$(kubectl -n kube-system get pods -l k8s-app=kube-dns \
      -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -cv '^Running$')

    if [ "$NOTRUNNING" == "0" ]; then
      # And the work from the earlier steps must have survived the recovery.
      WEB=$(kubectl exec dnstools -- dig +short web.default.svc.cluster.local 2>/dev/null | tr -d '[:space:]')
      DB=$(kubectl exec dnstools -- dig +short db.corp.internal 2>/dev/null | tr -d '[:space:]')
      LEGACY=$(kubectl exec dnstools -- dig +short legacy-api.example.com 2>/dev/null | tr -d '[:space:]')

      [ "$WEB" == "$CLUSTER_IP" ] && [ "$DB" == "10.99.0.42" ] && [ "$LEGACY" == "$CLUSTER_IP" ] && pass
    fi
  fi
  sleep 5
done

fail \
  "The Corefile is repaired, but the cluster has not come all the way back." \
  "" \
  "  coredns ready:                 ${READY:-0} of ${DESIRED:-0}" \
  "  web.default.svc.cluster.local  ->  ${WEB:-<nothing>}   (expected $CLUSTER_IP)" \
  "  db.corp.internal               ->  ${DB:-<nothing>}   (expected 10.99.0.42)" \
  "  legacy-api.example.com         ->  ${LEGACY:-<nothing>}   (expected $CLUSTER_IP)" \
  "" \
  "Pods that crashed on the broken config stay down until they are restarted," \
  "and the stub zone and rewrite from steps 2 and 3 have to still be in the" \
  "repaired file:" \
  "  kubectl -n kube-system get pods -l k8s-app=kube-dns" \
  "  kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20" \
  "  kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'"
