#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · One reason per node, and only the first"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

kubectl get pod job >/dev/null 2>&1 || fail \
  "There is no Pod called 'job'." \
  "" \
  "Put it back:  kubectl apply -f /root/job.yaml"

FILE=/root/answers/step1
[ -s "$FILE" ] || fail \
  "There is no prediction in $FILE yet." \
  "" \
  "Write how many nodes will say each reason once the taint is tolerated:" \
  "  echo \"cpu=<n> selector=<n>\" > $FILE" \
  "" \
  "The message now: kubectl get events --field-selector involvedObject.name=job"

# The newest FailedScheduling message for the Pod: what the cluster says NOW.
MSG=$(kubectl get events --field-selector involvedObject.name=job,reason=FailedScheduling \
  --sort-by=.lastTimestamp -o jsonpath='{.items[-1:].message}' 2>/dev/null)

echo "$MSG" | grep -q 'untolerated' && fail \
  "The message still reports untolerated taints, so 'job' does not tolerate them yet." \
  "" \
  "  kubectl get events --field-selector involvedObject.name=job --sort-by=.lastTimestamp | tail -1" \
  "" \
  "Make it tolerate the taint on those nodes, wait a few seconds, and read the message again." \
  "(A Pod's tolerations can be added to in place.)"

[ -n "$MSG" ] || fail \
  "There is no FailedScheduling message for 'job' yet." \
  "" \
  "  kubectl describe pod job | tail"

# Counts as the cluster reports them. The first "N Insufficient cpu" and the first
# "N node(s) didn't match ... selector" belong to the filter half of the message;
# the preemption half has neither phrase.
CPU=$(echo "$MSG" | grep -oE '[0-9]+ Insufficient cpu' | head -1 | grep -oE '^[0-9]+')
SEL=$(echo "$MSG" | grep -oE "[0-9]+ node\(s\) didn't match Pod's node affinity/selector" | head -1 | grep -oE '^[0-9]+')
CPU=${CPU:-0}; SEL=${SEL:-0}

PCPU=$(grep -oiE 'cpu[^0-9]*[0-9]+' "$FILE" | head -1 | grep -oE '[0-9]+$')
PSEL=$(grep -oiE 'selector[^0-9]*[0-9]+' "$FILE" | head -1 | grep -oE '[0-9]+$')
[ -n "$PCPU" ] && [ -n "$PSEL" ] || fail \
  "Could not read two numbers out of $FILE (it says: $(head -c 80 "$FILE"))." \
  "" \
  "Write it as:  echo \"cpu=<n> selector=<n>\" > $FILE"

[ "$PCPU" == "$CPU" ] && [ "$PSEL" == "$SEL" ] || fail \
  "Your prediction does not match what the cluster says now." \
  "" \
  "  you wrote:  cpu=$PCPU selector=$PSEL" \
  "" \
  "Read the newest message and work out which nodes it counts under each reason:" \
  "  kubectl get events --field-selector involvedObject.name=job --sort-by=.lastTimestamp | tail -1" \
  "" \
  "Each node is counted once, under the FIRST thing that failed. A node that is both full and" \
  "unlabelled says only one of the two, and which one depends on the order the scheduler checks."

pass
