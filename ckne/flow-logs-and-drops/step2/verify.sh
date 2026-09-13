#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · Why it stopped, not that it stopped"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

kubectl get netpol api-deny >/dev/null 2>&1 || fail \
  "There is no NetworkPolicy named 'api-deny'." \
  "" \
  "A default-deny is a policy that selects api, names Ingress in policyTypes," \
  "and has no ingress rules at all. See the Tip for the manifest."

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Write the verdict string Hubble prints on the blocked flows:" \
  "  flows --since 120s --to-pod api --verdict DROPPED" \
  "  echo '<verdict string>' > $ANSWER"

grep -qi "policy denied" "$ANSWER" || fail \
  "$ANSWER does not hold the verdict string Hubble reports." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "Look at the end of a dropped flow line -- the reason Hubble gives is the" \
  "answer, quoted as it appears:" \
  "  flows --since 120s --to-pod api --verdict DROPPED"

# The drop must be real and observable, not just asserted in the file.
for _ in $(seq 1 12); do
  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    hubble observe --since 120s --to-pod api --verdict DROPPED 2>/dev/null \
    | grep -q "Policy denied" && pass
  sleep 5
done

fail \
  "'api-deny' exists and your answer is right, but no dropped flow to api appeared in the last 120s." \
  "" \
  "A verdict only shows up when something actually tries. Send traffic, then" \
  "press CHECK again:" \
  "  apicall" \
  "  flows --since 120s --to-pod api --verdict DROPPED" \
  "" \
  "If the callers have stopped, check they are running:" \
  "  kubectl get pods -o wide"
