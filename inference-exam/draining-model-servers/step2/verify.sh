#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · Raised, and still cut"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/drain-lab.sh

GRACE=$(dep '{.spec.template.spec.terminationGracePeriodSeconds}')
[ "${GRACE:-0}" -ge 90 ] 2>/dev/null || fail \
  "The chat Deployment's grace period is ${GRACE:-unset}s; this step wants at least 90." \
  "" \
  "It is a field of the Pod template, beside 'containers':" \
  "  kubectl patch deploy chat -p '{\"spec\":{\"template\":{\"spec\":{\"terminationGracePeriodSeconds\":120}}}}'" \
  "  kubectl rollout status deploy/chat"

CUT=
while read -r line; do
  [ -z "$line" ] && continue
  g=$(field "$line" grace)
  [ "${g:-0}" -ge 90 ] 2>/dev/null && CUT=1
done < <(drills_where prestop=none done=no)
[ -n "$CUT" ] || fail \
  "There is no record of a drill run with a grace period of 90s or more." \
  "" \
  "Run one now that the Deployment has the longer grace period:" \
  "  drill" \
  "" \
  "Then compare how long the old Pod lasted with the time it was given."

FILE=/root/answers/step2
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "The old Pod's log says why the stream was cut, and the log goes with the Pod." \
  "Listen before the drill starts:" \
  "  kubectl logs -f deploy/chat > /tmp/old.log 2>&1 &" \
  "  drill" \
  "  grep -i -E 'shutdown|drain' /tmp/old.log" \
  "" \
  "Then copy the line that explains the cut into $FILE."

grep -qi 'drain timed out' "$FILE" || fail \
  "$FILE does not hold the line that explains the cut. It says:" \
  "  $(head -c 200 "$FILE")" \
  "" \
  "The server logs three things after the shutdown signal. One of them says it" \
  "stopped waiting for the request still open, and how many were open:" \
  "  grep -i -E 'shutdown|drain' /tmp/old.log"

pass
