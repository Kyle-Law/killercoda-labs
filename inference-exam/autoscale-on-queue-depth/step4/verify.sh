#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · And nobody got faster"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The backlog builds before the scale-up, so it is on the replica that existed
# then: the oldest one.
OLDEST=$(kubectl -n serve get pods -l app=chat --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

FILE=/root/answers/step4
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Find the replica that is still holding a queue while the others are idle:" \
  "  llmstats" \
  "and write its Pod name:" \
  "  echo <pod-name> > $FILE"

grep -q "$OLDEST" "$FILE" || fail \
  "$FILE does not name the replica holding the backlog. It says:" \
  "  $(head -c 120 "$FILE")" \
  "" \
  "Compare each Pod's age with its WAITING count:" \
  "  kubectl get pods -l app=chat --sort-by=.metadata.creationTimestamp" \
  "  llmstats" \
  "" \
  "If every queue is already empty, the backlog has drained. It built up while" \
  "there was only one replica, so ask which replica that was."

pass
