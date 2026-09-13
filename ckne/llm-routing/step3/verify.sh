#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · The model name is in the wrong place"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

GW=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=llm-gateway \
  -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
[ -n "$GW" ] || fail \
  "No data-plane Service for 'llm-gateway' -- the Gateway from step 1 is gone or unprogrammed." \
  "" \
  "  kubectl get gateway llm-gateway" \
  "  kubectl -n envoy-gateway-system get pods,svc"

ROUTE=$(kubectl get httproute chat-route -o json 2>/dev/null)
[ -n "$ROUTE" ] || fail \
  "There is no HTTPRoute named 'chat-route'." \
  "" \
  "Recreate it -- see the Solution in step 1 for the shape."

echo "$ROUTE" | grep -q '"embed"' || fail \
  "'chat-route' has no rule sending anything to the 'embed' Service." \
  "" \
  "tiny-embed is served by its own Deployment behind the 'embed' Service. The" \
  "route needs a rule whose backendRef is 'embed', plus the existing rule to" \
  "'chat' kept as the fallback for everything else."

echo "$ROUTE" | grep -qi 'x-model' || fail \
  "'chat-route' has no header match on 'x-model'." \
  "" \
  "Check what an HTTPRoute can match on:" \
  "  kubectl explain httproute.spec.rules.matches" \
  "" \
  "headers, method, path, queryParams -- and the model name is in none of them," \
  "because it lives in the JSON body. Lift it into a header the router can see:" \
  "  matches:" \
  "  - headers:" \
  "    - name: x-model" \
  "      value: tiny-embed"

# Envoy takes a few seconds to reprogram after a route change, so retry rather
# than failing a learner who pressed CHECK immediately.
for _ in 1 2 3 4; do
  WITH=$(kubectl exec cli -- curl -s -m 15 -w ' [http %{http_code}]' -X POST "http://$GW/v1/chat/completions" \
    -H 'Content-Type: application/json' -H 'x-model: tiny-embed' \
    -d '{"model":"tiny-embed","messages":[{"role":"user","content":"hello"}],"max_tokens":40}' 2>/dev/null)

  # Routed correctly: a real completion from the tiny-embed server, not a 404.
  if echo "$WITH" | grep -q '"model":"tiny-embed"' && ! echo "$WITH" | grep -q 'does not exist'; then
    # ...and the default route must still serve demo-model traffic.
    DEF=$(kubectl exec cli -- curl -s -m 15 -w ' [http %{http_code}]' -X POST "http://$GW/v1/chat/completions" \
      -H 'Content-Type: application/json' \
      -d '{"model":"demo-model","messages":[{"role":"user","content":"hi"}],"max_tokens":20}' 2>/dev/null)
    echo "$DEF" | grep -q '"model":"demo-model"' && pass

    fail \
      "A request WITH the x-model header now reaches tiny-embed -- but one WITHOUT it no longer works." \
      "" \
      "A plain demo-model request (no x-model header) came back with:" \
      "  $(echo "$DEF" | head -c 200)" \
      "" \
      "The header match must be an extra rule, not a replacement. Keep a second," \
      "match-less rule pointing at 'chat' so unheadered traffic still has a home --" \
      "and keep the timeouts from step 1 on both rules."
  fi
  sleep 5
done

fail \
  "The route has the header match, but a request carrying 'x-model: tiny-embed' still does not reach the embed server." \
  "" \
  "It came back with:" \
  "  $(echo "$WITH" | head -c 250)" \
  "" \
  "'The model tiny-embed does not exist' means the request is still landing on a" \
  "demo-model server -- the matching rule is not winning. Check:" \
  "  - the header VALUE is exactly 'tiny-embed'" \
  "  - the rule with the match comes before the catch-all rule" \
  "  - the route is still Accepted:" \
  "      kubectl get httproute chat-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\\n'" \
  "  - Envoy needs ~10s after an apply; press CHECK again"
