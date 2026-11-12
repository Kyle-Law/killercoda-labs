#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · Delay the signal, not the kill"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/drain-lab.sh

LC=$(dep '{.spec.template.spec.containers[0].lifecycle.preStop}')
case "$LC" in
  *'"exec":'*) fail \
    "The sim container still has an exec preStop hook." \
    "" \
    "The image has no sleep binary, so that hook fails every time. Replace the" \
    "whole lifecycle with the built-in sleep action:" \
    "  kubectl patch deploy chat --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/lifecycle\",\"value\":{\"preStop\":{\"sleep\":{\"seconds\":60}}}}]'" ;;
  *'"sleep":'*) ;;
  *) fail \
    "The sim container has no preStop sleep action." \
    "" \
    "  Current preStop: ${LC:-none}" \
    "" \
    "The kubelet can wait before SIGTERM by itself, with no command in the image:" \
    "  lifecycle: {preStop: {sleep: {seconds: 60}}}" ;;
esac

SLEEP=$(dep '{.spec.template.spec.containers[0].lifecycle.preStop.sleep.seconds}')
GRACE=$(dep '{.spec.template.spec.terminationGracePeriodSeconds}')
[ "${GRACE:-30}" -gt "${SLEEP:-0}" ] 2>/dev/null || fail \
  "The grace period (${GRACE:-30}s) is not longer than the preStop sleep (${SLEEP}s)." \
  "" \
  "The hook runs inside the grace period. When the grace period ends the kubelet" \
  "kills the container, sleeping or not, and the answer is cut again. Give it" \
  "room for the sleep and the server's drain after it:" \
  "  kubectl patch deploy chat -p '{\"spec\":{\"template\":{\"spec\":{\"terminationGracePeriodSeconds\":120}}}}'"

OK=$(drills_where "prestop=sleep:$SLEEP" done=yes chunks=100 rc=0)
if [ -z "$OK" ]; then
  LAST=$(drills_where "prestop=sleep:$SLEEP" | tail -1)
  [ -z "$LAST" ] && fail \
    "No drill has run with the current configuration (sleep ${SLEEP}s, grace ${GRACE}s)." \
    "" \
    "Wait for the rollout, then run it:" \
    "  kubectl rollout status deploy/chat" \
    "  drill"
  fail \
    "The last drill with a ${SLEEP}s sleep still cut the answer:" \
    "  $LAST" \
    "" \
    "The answer starts 5s before the restart and lasts about 50s. After the" \
    "restart it gets the sleep, then the server's 30s drain once SIGTERM arrives," \
    "and both have to fit inside the grace period:" \
    "  - gone well before 'grace' seconds: the sleep plus the drain ran out, so" \
    "    make the sleep longer;" \
    "  - gone at about 'grace' seconds: the kubelet killed the server during its" \
    "    drain, so make the grace period longer than the sleep plus 30." \
    "Then drill again."
fi

pass
