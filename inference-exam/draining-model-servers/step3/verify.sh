#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · The hook that never ran"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/drain-lab.sh

if [ -z "$(drills_where prestop=exec)" ]; then
  LC=$(dep '{.spec.template.spec.containers[0].lifecycle.preStop}')
  if [ -z "$LC" ]; then
    fail \
      "The sim container has no preStop hook yet, and no drill has run with one." \
      "" \
      "Add the runbook's hook exactly as written, then run the drill:" \
      "  kubectl patch deploy chat --type=strategic -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"sim\",\"lifecycle\":{\"preStop\":{\"exec\":{\"command\":[\"sleep\",\"60\"]}}}}]}}}}'" \
      "  kubectl rollout status deploy/chat" \
      "  drill"
  fi
  fail \
    "There is no record of a drill run with the exec preStop hook in place." \
    "" \
    "The hook on the Deployment right now is:" \
    "  $LC" \
    "" \
    "This step is about the runbook's exec hook. Put that one on and run:" \
    "  drill"
fi

FILE=/root/answers/step3
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "The kubelet reported what happened to the hook as an event:" \
  "  kubectl get events --sort-by=.lastTimestamp | tail -8" \
  "" \
  "Write the event's reason -- its one-word name -- into $FILE."

grep -q 'FailedPreStopHook' "$FILE" || fail \
  "'$(head -c 80 "$FILE")' is not the event's reason." \
  "" \
  "It is the REASON column of a Warning event on the old Pod, written as one" \
  "CamelCase word:" \
  "  kubectl get events --sort-by=.lastTimestamp | grep -i hook"

pass
