#!/bin/bash
LOG=/root/.check
STEP="Step 2 · Turn the lights on"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

kubectl get pod scored >/dev/null 2>&1 || fail \
  "There is no Pod called 'scored'." \
  "" \
  "  kubectl apply -f /root/scored.yaml"

NODE=$(kubectl get pod scored -o jsonpath='{.spec.nodeName}' 2>/dev/null)
[ -n "$NODE" ] || fail \
  "'scored' has no node yet." \
  "" \
  "  kubectl describe pod scored | tail" \
  "  kubectl -n kube-system get pods -l component=kube-scheduler"

# The scheduler's own record of that decision.
LOGTXT=$(kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 2>/dev/null)
TOTAL=$(echo "$LOGTXT" | grep "Calculated node's final score for pod" | grep 'pod="default/scored"' \
  | grep "node=\"$NODE\"" | tail -1 | sed -E 's/.*score=([0-9]+).*/\1/')

[ -n "$TOTAL" ] || fail \
  "The scheduler's log has no score for 'scored' on $NODE." \
  "" \
  "It is probably not logging scores, or 'scored' was placed before it was:" \
  "  kubectl -n kube-system get pod -l component=kube-scheduler -o jsonpath='{.items[0].spec.containers[0].command}'" \
  "" \
  "Score logging for one file is  --vmodule=schedule_one=10  on the scheduler's command line." \
  "If you added it after creating 'scored', delete the Pod and apply it again."

FILE=/root/answers/step2
[ -s "$FILE" ] || fail \
  "The scheduler logged a total for $NODE, but there is no answer in $FILE yet." \
  "" \
  "Add up the plugin scores for that node yourself, and check them against the total:" \
  "  scores scored $NODE" \
  "" \
  "Then:  echo \"score=<the node's TOTAL> weight=<TaintToleration's weight>\" > $FILE"

SCORE=$(grep -oiE 'score[^0-9]*[0-9]+' "$FILE" | head -1 | grep -oE '[0-9]+$')
WEIGHT=$(grep -oiE 'weight[^0-9]*[0-9]+' "$FILE" | head -1 | grep -oE '[0-9]+$')
[ -n "$SCORE" ] && [ -n "$WEIGHT" ] || fail \
  "Could not read two numbers out of $FILE (it says: $(head -c 80 "$FILE"))." \
  "" \
  "Write it as:  echo \"score=<n> weight=<n>\" > $FILE"

[ "$SCORE" == "$TOTAL" ] || fail \
  "The score you wrote ($SCORE) is not the scheduler's total for the node 'scored' landed on." \
  "" \
  "  It landed on: $NODE" \
  "  scores scored $NODE" \
  "" \
  "Add the plugin lines yourself first. If your sum does not match the TOTAL line, something about" \
  "what a logged score means is not what you assumed."

[ "$WEIGHT" == "3" ] || fail \
  "The weight you wrote for TaintToleration ($WEIGHT) is not right." \
  "" \
  "  scores scored $NODE | grep TaintToleration" \
  "" \
  "A plugin scores a node from 0 to 100. Compare that with what is logged."

pass
