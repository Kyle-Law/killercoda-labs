#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · Three quarters of an answer"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/drain-lab.sh

[ -n "$(drills_where grace=30 done=no)" ] || fail \
  "There is no record of a drill that cut an answer on the default configuration." \
  "" \
  "Run it -- it takes about a minute:" \
  "  drill" \
  "" \
  "If you have already changed the Deployment, this step wanted the drill run" \
  "before that. Its record is in /root/drills.log:" \
  "  cat /root/drills.log"

FILE=/root/answers/step1
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write the number of seconds the old Pod was given between SIGTERM and SIGKILL:" \
  "  echo <seconds> > $FILE" \
  "" \
  "The field is in the Pod template, filled in by the API server:" \
  "  kubectl get deploy chat -o yaml | grep -i grace"

grep -qwE '30' "$FILE" || fail \
  "'$(head -c 60 "$FILE")' is not the grace period." \
  "" \
  "drill said how long the old Pod lasted, a little more than the limit itself." \
  "Read the limit rather than the measurement:" \
  "  kubectl get deploy chat -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}'"

pass
