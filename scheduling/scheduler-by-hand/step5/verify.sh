#!/bin/bash
LOG=/root/.check
STEP="Step 5 · Failed is terminal"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# Failed Pods that were placed by the learner's scheduler. Counted by the name
# the Pod gave, so a Failed Pod from anywhere else does not move the number.
failed_count() {
  kubectl get pods -A --field-selector status.phase=Failed \
    -o jsonpath='{range .items[*]}{.spec.schedulerName}{"\n"}{end}' 2>/dev/null \
    | grep -cx by-hand
}

FILE=/root/answers/step5
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write the number of Failed Pods there were when you stopped it:" \
  "  echo <number> > $FILE" \
  "" \
  "Count them (before you delete anything) with:" \
  "  kubectl get pods --field-selector status.phase=Failed --no-headers | wc -l" \
  "" \
  "If you have not started it yet: run your loop, then  kubectl apply -f /root/big.yaml"

N=$(grep -oE '[0-9]+' "$FILE" | head -1)
[ -n "$N" ] || fail \
  "There is no number in $FILE (it says: $(head -c 60 "$FILE"))." \
  "" \
  "Write just the count, for example:  echo 84 > $FILE"

[ "$N" -ge 10 ] || fail \
  "$N is too few for what this does." \
  "" \
  "With your scheduler running and /root/big.yaml applied, the count of Failed Pods" \
  "climbs by more than one a second. If you stopped at $N, it was not running" \
  "against the oversized Deployment for long. Start it again:" \
  "  kubectl apply -f /root/big.yaml" \
  "and count again when you stop it."

# The cycle is stopped if the count is not moving. Two samples, with time
# between them for the ReplicaSet to have made several more.
A=$(failed_count)
sleep 12
B=$(failed_count)

[ "$B" -le "$A" ] || fail \
  "It is still going. Failed Pods placed by 'by-hand': $A, then $B twelve seconds later." \
  "" \
  "Two things feed each other here -- find both:" \
  "  pgrep -af by-hand                    (something is still placing Pods)" \
  "  kubectl get deployment big -o yaml   (something keeps asking for replacements)" \
  "" \
  "Stopping either one breaks the cycle."

pass
