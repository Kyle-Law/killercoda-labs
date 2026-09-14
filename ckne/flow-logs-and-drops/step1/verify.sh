#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · Names, not addresses"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ANSWER=/root/answers/step1.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Write the number in brackets next to api in the flow log:" \
  "  echo '<number>' > $ANSWER"

CLAIM=$(tr -dc '0-9' < "$ANSWER")
[ -n "$CLAIM" ] || fail \
  "$ANSWER contains no number." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "The answer is the bracketed number itself, nothing else."

# Read the real identity straight from Cilium rather than trusting the answer,
# so a guessed number cannot pass.
for _ in $(seq 1 12); do
  REAL=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    cilium-dbg endpoint list 2>/dev/null | awk '/k8s:app=api/{print $4; exit}')
  [ -n "$REAL" ] && break
  sleep 5
done
[ -n "$REAL" ] || fail \
  "Could not read api's identity from the Cilium agent, so your answer cannot be checked." \
  "" \
  "The agent may still be starting. Check it, then press CHECK again:" \
  "  kubectl -n kube-system get pods -l k8s-app=cilium" \
  "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg endpoint list"

[ "$CLAIM" == "$REAL" ] && pass

fail \
  "$CLAIM is not api's security identity." \
  "" \
  "Identities are assigned per distinct label set, so every Pod of one workload" \
  "shares one and it survives a restart. Read api's from the agent itself and" \
  "make sure you are on api's row, not web's or scanner's:" \
  "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \\" \
  "    cilium-dbg endpoint list | grep -E 'IDENTITY|k8s:app='" \
  "" \
  "It is the IDENTITY column -- not the endpoint ID in the first column, and not" \
  "the Pod's address."
