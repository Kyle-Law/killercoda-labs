#!/bin/bash
LOG=/root/.check
STEP="Step 4 · A field with two values and one behaviour"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ANSWER=/root/answers/step4.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Take the picker away and send a request under each failureMode, timing both:" \
  "  kubectl scale deploy llm-epp --replicas=0" \
  "  poolcall" \
  "  kubectl patch inferencepool llm-pool --type=merge \\" \
  "    -p '{\"spec\":{\"endpointPickerRef\":{\"failureMode\":\"FailClose\",\"name\":\"llm-epp\",\"port\":{\"number\":9002}}}}'" \
  "  poolcall" \
  "Then put the picker back and write down what you found."

grep -qiE "failopen|fail open" "$ANSWER" || fail \
  "$ANSWER does not mention FailOpen." \
  "" \
  "It currently says:" \
  "  $(head -c 220 "$ANSWER")" \
  "" \
  "That is the default this pool has been running with all along, and the name" \
  "makes a promise. Say whether it kept it."

grep -qiE "failclose|fail close|same|identical|no difference|neither" "$ANSWER" || fail \
  "$ANSWER does not compare the two values." \
  "" \
  "It currently says:" \
  "  $(head -c 220 "$ANSWER")" \
  "" \
  "You measured both. The finding is what the difference between them was, from" \
  "outside, with the picker gone."

# The lab has to end working: picker back, traffic flowing.
READY=$(kubectl get deploy llm-epp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -ge 1 ] || fail \
  "The picker is still scaled to zero." \
  "" \
  "Put it back before finishing:" \
  "  kubectl scale deploy llm-epp --replicas=1" \
  "  kubectl rollout status deploy llm-epp"

P=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
for _ in 1 2 3 4 5; do
  B=$(curl -s -m 25 "http://localhost:$P/v1/completions" -H 'Content-Type: application/json' \
      -d '{"model":"Qwen/Qwen3-32B","prompt":"hello","max_tokens":20}' 2>/dev/null)
  echo "$B" | grep -q '"text_completion"' && pass
  sleep 5
done
fail \
  "The picker is Ready again but requests are not succeeding." \
  "" \
  "  what came back: $(echo "$B" | head -c 200)" \
  "" \
  "The gateway takes a few seconds to resolve the picker's endpoint after it" \
  "comes back -- try CHECK again. If it persists:" \
  "  pickerlog" \
  "  kubectl get inferencepool llm-pool -o jsonpath='{.spec.endpointPickerRef}'"
