#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · One integer"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

CM=$(kubectl get cm vllm-qwen3-32b-epp -o yaml 2>/dev/null)
[ -n "$CM" ] || fail \
  "Could not read the endpoint picker's ConfigMap." \
  "" \
  "  kubectl get cm | grep epp"

# The prefix weight has to have come down from its default of 3.
W=$(echo "$CM" | grep -A6 -i "prefix-cache-scorer" | grep -iE "^\s*weight:" | head -1 | awk '{print $2}')
[ -n "$W" ] || fail \
  "Could not find a weight for the prefix-cache scorer in the ConfigMap." \
  "" \
  "  kubectl get cm vllm-qwen3-32b-epp -o yaml | grep -B2 -A4 -i weight" \
  "" \
  "The scorer plugins and their weights are in that ConfigMap. Lower the one for" \
  "the prefix-cache scorer, then restart the picker so it re-reads it."

[ "$W" -le 2 ] 2>/dev/null || fail \
  "The prefix-cache scorer still has weight $W." \
  "" \
  "At 3 it cannot lose to a queue: a queue is worth at most 2 points, so the" \
  "replica holding the prefix wins regardless of how deep its backlog is. Bring" \
  "it down and restart the picker:" \
  "  kubectl edit cm vllm-qwen3-32b-epp" \
  "  kubectl rollout restart deploy vllm-qwen3-32b-epp" \
  "  kubectl rollout status deploy vllm-qwen3-32b-epp"

READY=$(kubectl get deploy vllm-qwen3-32b-epp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -ge 1 ] || fail \
  "The endpoint picker is not Ready, so the new weight is not in force." \
  "" \
  "It only reads that ConfigMap at startup -- editing it changes nothing until" \
  "the picker restarts:" \
  "  kubectl rollout status deploy vllm-qwen3-32b-epp"

PORT=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
[ -n "$PORT" ] || fail \
  "The Gateway from step 1 is gone, so the result cannot be measured." \
  "" \
  "  kubectl get gateway inference-gateway"

snap() {
  for p in $(kubectl get pod -l app=vllm-qwen3-32b -o jsonpath='{.items[*].metadata.name}'); do
    n=$(kubectl get --raw "/api/v1/namespaces/default/pods/$p:8000/proxy/metrics" 2>/dev/null \
        | grep -E '^vllm:request_success_total' | awk '{s+=$2} END {print s+0}')
    echo "$p ${n:-0}"
  done
}

# Measured, not asserted: the same long-prompt load must now reach more than one
# replica. Retried because the picker's prefix table is rebuilt from scratch
# after a restart and the first run can still look concentrated.
for attempt in 1 2; do
  BEFORE=$(snap)
  SYS=$(for i in $(seq 1 30); do printf "You are a helpful restaurant assistant. Rule %s: be polite. " "$i"; done)
  export PORT SYS
  seq 1 40 | xargs -P 10 -I{} bash -c '
    curl -s -o /dev/null -m 60 "http://localhost:$PORT/v1/completions" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"Qwen/Qwen3-32B\",\"prompt\":\"$SYS Question {}: what is good today?\",\"max_tokens\":20}"' \
    >/dev/null 2>&1
  AFTER=$(snap)

  SERVED=$(echo "$BEFORE" | while read -r pod before; do
    after=$(echo "$AFTER" | awk -v p="$pod" '$1==p {print $2}')
    echo "$pod $(( ${after:-0} - before ))"
  done)
  TOTAL=$(echo "$SERVED" | awk '{s+=$2} END {print s+0}')
  USED=$(echo "$SERVED" | awk '$2 >= 4 {c++} END {print c+0}')
  [ "$TOTAL" -ge 30 ] && [ "$USED" -ge 2 ] && pass
  sleep 5
done

fail \
  "The weight is $W, but the traffic still is not spreading." \
  "" \
  "  requests served this run, per replica:" \
  "$(echo "$SERVED" | sed 's/^/    /')" \
  "  total served: ${TOTAL:-0} of 40   replicas taking a real share: ${USED:-0}" \
  "" \
  "A total well under 40 means requests are failing rather than being routed --" \
  "check the simulators are Ready and the gateway still resolves:" \
  "  kubectl get pods -l app=vllm-qwen3-32b" \
  "  kubectl get httproute llm-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\\n'" \
  "" \
  "Everything on one replica with the weight already lowered usually means the" \
  "picker never restarted, so it is still running with the old value in memory:" \
  "  kubectl rollout restart deploy vllm-qwen3-32b-epp"
