#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · 80/20 is a target, not a guarantee"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 24); do
  W1=$(kubectl get httproute web-route -o jsonpath='{.spec.rules[0].backendRefs[?(@.name=="web")].weight}' 2>/dev/null)
  W2=$(kubectl get httproute web-route -o jsonpath='{.spec.rules[0].backendRefs[?(@.name=="web-canary")].weight}' 2>/dev/null)
  [ "$W1" == "80" ] && [ "$W2" == "20" ] || { R="weights"; sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { R="gwip"; sleep 5; continue; }

  RESULTS=$(kubectl exec client -- /bin/sh -c "
    for i in \$(seq 1 200); do
      wget -qO- -T3 --header='Host: web.example.com' http://$GWIP/hostname
      echo
    done" 2>/dev/null)

  CANARY_COUNT=$(echo "$RESULTS" | grep -c '^web-canary-')
  TOTAL=$(echo "$RESULTS" | grep -c '^web-')

  # Generous tolerance around the 20% target -- this only needs to prove the
  # split is real and roughly in the right ballpark, not land on an exact
  # number, since 200 independent draws won't reproduce 20% precisely.
  if [ "$TOTAL" -ge 190 ] && [ "$CANARY_COUNT" -ge 10 ] && [ "$CANARY_COUNT" -le 45 ]; then
    pass
  fi
  R="split"
  sleep 5
done

case "$R" in
  weights) fail \
    "The first rule's backends are not weighted 80/20." \
    "" \
    "  web:        ${W1:-<unset>}" \
    "  web-canary: ${W2:-<unset>}" \
    "" \
    "Both backends go in ONE rule with a weight each -- two separate rules would" \
    "be a precedence question, not a split. An unset weight defaults to 1:" \
    "  kubectl get httproute web-route -o yaml | tail -30" ;;
  gwip) fail \
    "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
    "" \
    "  kubectl -n envoy-gateway-system get pods,svc" ;;
  *) fail \
    "The weights are right, but 200 requests did not land anywhere near 80/20." \
    "" \
    "  answered:        ${TOTAL:-0} of 200" \
    "  went to canary:  ${CANARY_COUNT:-0}   (this check accepts 10 to 45)" \
    "" \
    "Fewer than 190 answers means requests are failing rather than splitting --" \
    "check both backends have running Pods, since a weight pointing at a backend" \
    "with no endpoints does not get redistributed, it just fails:" \
    "  kubectl get pods -l 'app in (web,web-canary)'" \
    "  kubectl get endpointslices" \
    "" \
    "Zero to canary with everything answering usually means the header rule from" \
    "step 2 is still catching the traffic before the weighted rule sees it." ;;
esac
