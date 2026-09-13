#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · The answer that stops halfway"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

kubectl get gateway llm-gateway >/dev/null 2>&1 || fail \
  "There is no Gateway named 'llm-gateway' in the default namespace." \
  "" \
  "The GatewayClass 'eg' already exists -- you only need the Gateway itself," \
  "with one HTTP listener on port 80. See the Tip for a manifest."

# Accepted, deliberately not Programmed: this cluster has no load-balancer
# controller, so the data plane's Service never gets an external address and
# the Gateway stays Programmed=False (AddressNotAssigned) while serving
# perfectly well on its ClusterIP. Gating on Programmed here would make the
# step impossible to pass.
ACC=$(kubectl get gateway llm-gateway \
  -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
[ "$ACC" == "True" ] || fail \
  "The Gateway 'llm-gateway' exists but has not been accepted (Accepted=${ACC:-<none>})." \
  "" \
  "Envoy Gateway takes a few seconds to pick up a new Gateway; if it stays this" \
  "way, the reason is in its status -- usually gatewayClassName is not 'eg':" \
  "  kubectl get gateway llm-gateway -o jsonpath='{.status.conditions}' | tr ',' '\\n'" \
  "" \
  "(Programmed=False with 'AddressNotAssigned' is normal here and is not a problem:" \
  "there is no cloud load balancer, and the lab reaches the Gateway on its ClusterIP.)"

kubectl get httproute chat-route >/dev/null 2>&1 || fail \
  "There is no HTTPRoute named 'chat-route'." \
  "" \
  "It needs parentRefs: [{name: llm-gateway}] and a backendRef to the chat-slow Service."

ACCEPTED=$(kubectl get httproute chat-route \
  -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
[ "$ACCEPTED" == "True" ] || fail \
  "'chat-route' is not Accepted by the Gateway (Accepted=${ACCEPTED:-<none>})." \
  "" \
  "Usually parentRefs names a Gateway that does not exist, or the listener does" \
  "not allow routes from this namespace. The reason is in the route status:" \
  "  kubectl get httproute chat-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\\n'"

# The route must carry an explicit timeout setting -- the default is what
# truncated the stream, so leaving it unset cannot be a pass.
TO=$(kubectl get httproute chat-route -o jsonpath='{.spec.rules[*].timeouts.request}' 2>/dev/null)
[ -n "$TO" ] || fail \
  "'chat-route' has no request timeout set, so it is still using Envoy's default." \
  "" \
  "That default is what cut the stream off. Set it explicitly on the rule:" \
  "  rules:" \
  "  - timeouts:" \
  "      request: \"0s\"" \
  "      backendRequest: \"0s\"" \
  "" \
  "'0s' means no timeout, which is what a streaming route needs."

GW=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=llm-gateway \
  -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
[ -n "$GW" ] || fail \
  "Envoy Gateway has not created a data-plane Service for 'llm-gateway' yet." \
  "" \
  "Check that its controller is running, then re-check in ~30s:" \
  "  kubectl -n envoy-gateway-system get pods,svc" \
  "" \
  "(An EXTERNAL-IP of <pending> on that Service is expected -- only the ClusterIP" \
  "is used here.)"

PROMPT=$(awk 'BEGIN{for(i=1;i<=50;i++) printf "word%d ", i}')

# 50 echoed tokens at 400ms is ~21s of streaming, so each attempt is slow on
# purpose: a stream that finishes inside 15s would prove nothing.
for _ in 1 2; do
  RESULT=$(kubectl exec cli -- curl -s -N -m 60 -o /tmp/verify1.txt \
    -w '%{time_total} %{http_code}' \
    -X POST "http://$GW/v1/chat/completions" -H 'Content-Type: application/json' \
    -d "{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":200,\"stream\":true}" \
    2>/dev/null)

  # A complete SSE stream ends with the [DONE] sentinel. That -- not the
  # status code, which was 200 even when truncated -- is the real check.
  kubectl exec cli -- grep -q 'DONE' /tmp/verify1.txt 2>/dev/null && pass
  sleep 5
done

CHUNKS=$(kubectl exec cli -- grep -c '^data:' /tmp/verify1.txt 2>/dev/null)
BODY=$(kubectl exec cli -- head -c 200 /tmp/verify1.txt 2>/dev/null)
BACKEND=$(kubectl get httproute chat-route -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)

fail \
  "The configuration looks right, but a streamed completion still does not finish." \
  "" \
  "  request timeout on the route: $TO" \
  "  backendRef:                   ${BACKEND:-<none>}" \
  "  elapsed / status:             ${RESULT:-<no response>}" \
  "  SSE chunks received:          ${CHUNKS:-0}" \
  "  no 'data: [DONE]' line -- the stream was cut off mid-answer" \
  "" \
  "First 200 bytes of what came back:" \
  "  ${BODY:-<empty>}" \
  "" \
  "Things to look at:" \
  "  - backendRequest as well as request: both must be lifted, the shorter wins" \
  "  - Envoy takes ~10s to reprogram after an HTTPRoute change; try CHECK again" \
  "  - is chat-slow running?  kubectl get pods -l speed=slow"
