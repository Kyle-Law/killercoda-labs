#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · Whichever rule is more specific wins"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 24); do
  RULE_COUNT=$(kubectl get httproute web-route -o jsonpath='{.spec.rules[*]}' 2>/dev/null | grep -o '"backendRefs"' | wc -l)
  [ "$RULE_COUNT" -ge 2 ] || { R="rules"; sleep 5; continue; }

  # The final state this step leaves things in is the header-based rule
  # (the second half of the solution) -- both a header condition and a
  # PathPrefix condition present somewhere in the route.
  kubectl get httproute web-route -o json 2>/dev/null | grep -q '"headers"' || { R="headers"; sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { R="gwip"; sleep 5; continue; }

  NO_HEADER=$(kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname" 2>/dev/null)
  WITH_HEADER=$(kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" --header="x-canary: true" "http://$GWIP:80/hostname" 2>/dev/null)

  # Precedence has to actually be observable, not just configured: the
  # unmatched request goes to web, the header-matched one goes to web-canary,
  # and they must differ from each other.
  echo "$NO_HEADER" | grep -q '^web-' || { R="plain"; sleep 5; continue; }
  echo "$WITH_HEADER" | grep -q '^web-canary-' || { R="canary"; sleep 5; continue; }
  [ "$NO_HEADER" != "$WITH_HEADER" ] && pass
  R="same"
  sleep 5
done

case "$R" in
  rules) fail \
    "'web-route' has ${RULE_COUNT:-0} rule(s); this step needs at least two." \
    "" \
    "One rule cannot demonstrate precedence. Add the more specific rule beside" \
    "the one that is already there:" \
    "  kubectl get httproute web-route -o yaml | tail -30" ;;
  headers) fail \
    "No rule in 'web-route' matches on a header." \
    "" \
    "The second half of this step routes on the x-canary header:" \
    "  matches:" \
    "  - headers:" \
    "    - name: x-canary" \
    "      value: \"true\"" ;;
  gwip) fail \
    "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
    "" \
    "  kubectl -n envoy-gateway-system get pods,svc" ;;
  plain) fail \
    "A request with no x-canary header did not reach the 'web' backend." \
    "" \
    "  response: ${NO_HEADER:-<nothing>}   (expected a web- Pod name)" \
    "" \
    "The header rule must be an addition, not a replacement -- traffic without" \
    "the header still needs a rule that matches it:" \
    "  kubectl get httproute web-route -o yaml | tail -30" ;;
  canary) fail \
    "A request carrying 'x-canary: true' did not reach the canary backend." \
    "" \
    "  response: ${WITH_HEADER:-<nothing>}   (expected a web-canary- Pod name)" \
    "" \
    "Header matches are exact and case-sensitive on the value. Precedence in" \
    "Gateway API is by specificity, not by order in the file -- but the rule has" \
    "to match at all before precedence matters:" \
    "  kubectl get httproute web-route -o yaml | tail -30" ;;
  *) fail \
    "Both requests reached the same backend, so no rule is winning over the other." \
    "" \
    "  without the header: ${NO_HEADER:-<nothing>}" \
    "  with the header:    ${WITH_HEADER:-<nothing>}" \
    "" \
    "The two rules have to point at different backends for the precedence to be" \
    "visible at all:" \
    "  kubectl get httproute web-route -o yaml | tail -30" ;;
esac
