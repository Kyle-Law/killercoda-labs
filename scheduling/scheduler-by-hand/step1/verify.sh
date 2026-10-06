#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · Pending, and no one has looked"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

FILE=/root/answers/step1
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write the name of the Pod that no scheduler has ever tried to place:" \
  "  echo <pod-name> > $FILE" \
  "" \
  "Compare what the cluster says about each of batch-1, batch-2 and batch-3 --" \
  "both its events and its status conditions."

ANS=$(tr -d '[:space:]' < "$FILE" | tr 'A-Z' 'a-z')

case "$ANS" in
  batch-1) pass ;;
  batch-2) fail \
    "batch-2 is not the one." \
    "" \
    "Its status says what is holding it:" \
    "  kubectl get pod batch-2 -o jsonpath='{.status.conditions}'" \
    "" \
    "Something wrote a reason onto it. The Pod you want has no such record at all." ;;
  batch-3) fail \
    "batch-3 is not the one." \
    "" \
    "A scheduler has read it, and said why it would not place it:" \
    "  kubectl describe pod batch-3 | tail -5" \
    "" \
    "That is a scheduler that looked and refused. The Pod you want has never been looked at." ;;
  *) fail \
    "'$(cat "$FILE")' is not the name of one of the three Pods." \
    "" \
    "Write just the Pod's name:  echo <pod-name> > $FILE" ;;
esac
