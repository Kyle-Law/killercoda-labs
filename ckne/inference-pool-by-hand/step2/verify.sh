#!/bin/bash
LOG=/root/.check
STEP="Step 2 · The permission it will not start without"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Take the 'pods' rule out of the picker's Role, restart it, and watch what" \
  "happens. Then write down what state the picker ends up in and how you found" \
  "out which permission was missing:" \
  "  kubectl edit role llm-epp" \
  "  kubectl rollout restart deploy llm-epp" \
  "  pickerlog" \
  "  echo '...' > $ANSWER"

grep -qiE "pods" "$ANSWER" || fail \
  "$ANSWER does not name the permission that was missing." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "The picker prints the exact resource it was refused, in its own logs, and" \
  "nothing else in the cluster says it:" \
  "  pickerlog"

grep -qiE "ready|readiness|health|start" "$ANSWER" || fail \
  "$ANSWER names the permission but not what the picker did about it." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "The point is what state it reached: it did not crash, and it did not carry on" \
  "regardless. Say which, because that is what decides whether a rollout of a" \
  "mis-permissioned picker takes your traffic down or quietly stalls."

# Whatever they broke has to be repaired: all three groups back.
ROLE=$(kubectl get role llm-epp -o json 2>/dev/null)
[ -n "$ROLE" ] || fail "The Role 'llm-epp' is gone entirely." "" "  kubectl get role llm-epp"
for r in inferencepools inferenceobjectives pods; do
  echo "$ROLE" | grep -q "\"$r\"" || fail \
    "The picker's Role no longer grants '$r'." \
    "" \
    "Restore every rule before moving on -- the picker watches all three, and a" \
    "missing one leaves it unable to start at all:" \
    "  kubectl get role llm-epp -o yaml"
done

READY=$(kubectl get deploy llm-epp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -ge 1 ] || fail \
  "The picker is not Ready (${READY:-0} replicas)." \
  "" \
  "Its readiness probe is a gRPC check, and it only passes once every watch the" \
  "picker needs has started:" \
  "  pickerlog"

P=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
for _ in 1 2 3 4; do
  B=$(curl -s -m 25 "http://localhost:$P/v1/completions" -H 'Content-Type: application/json' \
      -d '{"model":"Qwen/Qwen3-32B","prompt":"hello","max_tokens":20}' 2>/dev/null)
  echo "$B" | grep -q '"text_completion"' && pass
  sleep 5
done
fail \
  "The Role is repaired and the picker is Ready, but requests still fail." \
  "" \
  "  what came back: $(echo "$B" | head -c 200)" \
  "" \
  "  pickerlog"
