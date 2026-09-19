#!/bin/bash
LOG=/root/.check
STEP="Step 3 · Every object green, every request failing"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ANSWER=/root/answers/step3.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Delete the DestinationRule and send a request. Then check every Gateway API" \
  "object involved -- the Gateway, the route, the pool -- and write down what" \
  "they say versus what is actually happening:" \
  "  kubectl delete destinationrule llm-epp" \
  "  poolcall" \
  "  kubectl get gateway inference-gateway; kubectl get httproute llm-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\\n'" \
  "  echo '...' > $ANSWER"

grep -qiE "tls|destinationrule|destination rule" "$ANSWER" || fail \
  "$ANSWER does not say what the missing piece was." \
  "" \
  "It currently says:" \
  "  $(head -c 220 "$ANSWER")" \
  "" \
  "The picker serves its ext_proc endpoint over TLS. Something has to tell the" \
  "gateway that, and no field in the Gateway, the HTTPRoute or the InferencePool" \
  "can express it."

kubectl get destinationrule llm-epp >/dev/null 2>&1 || fail \
  "The DestinationRule is still deleted." \
  "" \
  "Put it back before moving on -- nothing else in the cluster can carry that" \
  "instruction:" \
  "  kubectl apply -f /root/destinationrule.yaml"

MODE=$(kubectl get destinationrule llm-epp -o jsonpath='{.spec.trafficPolicy.tls.mode}' 2>/dev/null)
[ "$MODE" == "SIMPLE" ] || fail \
  "The DestinationRule's TLS mode is '${MODE:-<unset>}', not SIMPLE." \
  "" \
  "  kubectl get destinationrule llm-epp -o yaml"

P=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
for _ in 1 2 3 4; do
  B=$(curl -s -m 25 "http://localhost:$P/v1/completions" -H 'Content-Type: application/json' \
      -d '{"model":"Qwen/Qwen3-32B","prompt":"hello","max_tokens":20}' 2>/dev/null)
  echo "$B" | grep -q '"text_completion"' && pass
  sleep 5
done
fail \
  "The DestinationRule is back but requests are still not succeeding." \
  "" \
  "  what came back: $(echo "$B" | head -c 200)" \
  "" \
  "Istio needs a moment to pick it up. If it persists, check the host it names" \
  "matches the picker's Service exactly:" \
  "  kubectl get destinationrule llm-epp -o jsonpath='{.spec.host}'" \
  "  kubectl get svc llm-epp"
