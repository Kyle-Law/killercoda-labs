#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · The metric the autoscaler needs"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ANSWER=/root/answers/step4.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Put load on, read llmstats while it is in flight, then write down the metric" \
  "an HPA should scale this workload on and the observation that rules out the" \
  "usual one:" \
  "  llmload 0.4 40 20 > /tmp/load.out 2>&1 &" \
  "  sleep 12" \
  "  llmstats" \
  "  cat > $ANSWER <<'TXT'" \
  "  ... your answer ..." \
  "  TXT"

# The metric itself -- accept the Prometheus name in either punctuation, since
# an HPA via prometheus-adapter sees it with underscores.
grep -qE "num_requests_waiting" "$ANSWER" || fail \
  "$ANSWER does not name the metric to scale on." \
  "" \
  "It currently says:" \
  "  $(head -c 250 "$ANSWER")" \
  "" \
  "The model server publishes the answer about itself. Read it directly:" \
  "  SLOW=\$(kubectl get pod -l speed=slow -o jsonpath='{.items[0].status.podIP}')" \
  "  kubectl exec cli -- curl -s \"http://\$SLOW:8000/metrics\" | grep '^vllm:num_requests'" \
  "" \
  "Two candidates come back. One pins at its --max-num-seqs ceiling and stays" \
  "there; the other keeps climbing for every user still waiting. Name that one."

# And the observation that rules CPU out. Naming the metric without knowing
# why CPU fails is the half-answer this step exists to prevent.
grep -qiE "cpu" "$ANSWER" || fail \
  "$ANSWER names the right metric but not why the default one fails." \
  "" \
  "It currently says:" \
  "  $(head -c 250 "$ANSWER")" \
  "" \
  "An HPA targets CPU utilisation unless told otherwise. Look at the CPU_mCORES" \
  "column for the replica that had a queue, and say what a 70%-CPU target" \
  "would have concluded about it."

# The workload must still be intact for the reading to have meant anything.
kubectl get deploy chat-slow >/dev/null 2>&1 || fail \
  "The 'chat-slow' Deployment is gone, so there was nothing to take a reading from." \
  "" \
  "  kubectl get deploy"

pass
