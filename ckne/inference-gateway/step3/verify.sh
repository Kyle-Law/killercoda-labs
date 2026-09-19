#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · A queue forms, and it loses anyway"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ARGS=$(kubectl get deploy vllm-qwen3-32b \
  -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
[ -n "$ARGS" ] || fail \
  "Could not read the simulator Deployment." \
  "" \
  "  kubectl get deploy vllm-qwen3-32b"

for flag in time-to-first-token inter-token-latency max-num-seqs; do
  echo "$ARGS" | grep -q -- "$flag" || fail \
    "The simulator is still missing --$flag." \
    "" \
    "By default it answers instantly, so no request ever waits and the queue" \
    "score is zero for every replica -- there is nothing for the picker to weigh." \
    "A queue has to exist before you can find out whether it matters." \
    "" \
    "  kubectl patch deploy vllm-qwen3-32b --type=json -p='[" \
    "   {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--time-to-first-token=500\"}," \
    "   {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--inter-token-latency=50\"}," \
    "   {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--max-num-seqs=2\"}]'" \
    "  kubectl rollout status deploy vllm-qwen3-32b" \
    "" \
    "Current args:" \
    "  $ARGS"
done

READY=$(kubectl get deploy vllm-qwen3-32b -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -ge 2 ] || fail \
  "Only ${READY:-0} simulator replicas are Ready, so there is nothing to compare against." \
  "" \
  "  kubectl rollout status deploy vllm-qwen3-32b" \
  "  kubectl get pods -l app=vllm-qwen3-32b"

ANSWER=/root/answers/step3.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Run the load again now that requests take real time, and explain the result:" \
  "  igload 60 long 10" \
  "  igqueue" \
  "" \
  "One replica should still be taking everything while the others sit idle." \
  "Work out why from the scorer weights, then write the reasoning down:" \
  "  kubectl get cm vllm-qwen3-32b-epp -o yaml | grep -A3 -i weight" \
  "  echo '...' > $ANSWER"

# The arithmetic is the finding. Accept it stated in either vocabulary, but it
# has to weigh the two scorers against each other rather than just name them.
grep -qiE "prefix" "$ANSWER" || fail \
  "$ANSWER does not mention the prefix score." \
  "" \
  "It currently says:" \
  "  $(head -c 250 "$ANSWER")" \
  "" \
  "The picker adds up weighted scores and routes to the highest total. Read the" \
  "weights it is using, then work out the best possible score for an idle replica" \
  "and the worst possible score for the replica holding the queue:" \
  "  kubectl get cm vllm-qwen3-32b-epp -o yaml | grep -A3 -i weight"

grep -qiE "queue|wait" "$ANSWER" || fail \
  "$ANSWER mentions the prefix score but not the queue score." \
  "" \
  "It currently says:" \
  "  $(head -c 250 "$ANSWER")" \
  "" \
  "The point is the comparison between the two: how many points a full queue can" \
  "take away, against how many points a prefix match is worth."

grep -q "3" "$ANSWER" || fail \
  "$ANSWER does not include the numbers." \
  "" \
  "It currently says:" \
  "  $(head -c 250 "$ANSWER")" \
  "" \
  "Each scorer returns a value from 0 to 1 relative to the other replicas, then" \
  "is multiplied by its weight. Put the actual arithmetic in the file -- the" \
  "totals for the queued replica and for an idle one, and which is higher."

pass
