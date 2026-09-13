#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · A balancer that cannot see load"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The route has to be serving both replicas, or none of this step happened.
BACKEND=$(kubectl get httproute chat-route -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)
[ "$BACKEND" == "chat" ] || fail \
  "'chat-route' still points at '${BACKEND:-<nothing>}', not the 'chat' Service." \
  "" \
  "Only 'chat' selects both replicas (app=chat), which is what puts a fast one" \
  "and a slow one behind the same load balancer:" \
  "  kubectl patch httproute chat-route --type=json \\" \
  "    -p='[{\"op\":\"replace\",\"path\":\"/spec/rules/0/backendRefs/0/name\",\"value\":\"chat\"}]'"

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Run the load, find the replica that is backed up, and write down which Pod" \
  "it is and how deep its queue is:" \
  "  llmload 0.4 40 20 > /tmp/load.out 2>&1 &" \
  "  sleep 12" \
  "  llmstats" \
  "  echo '<pod-name> is backed up: num_requests_waiting = N while chat-fast is idle' > $ANSWER"

# The finding is that the SLOW replica is the backed-up one. Naming the fast
# replica instead would be the opposite conclusion, so check both ways.
SLOW=$(kubectl get pod -l speed=slow -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
FAST=$(kubectl get pod -l speed=fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$SLOW" ] || fail \
  "No Pod with label speed=slow is running, so there is nothing to have found." \
  "" \
  "  kubectl get pods -l app=chat -L speed"

if ! grep -q "$SLOW" "$ANSWER" && ! grep -qi "chat-slow" "$ANSWER"; then
  fail \
    "$ANSWER does not name the replica that is in trouble." \
    "" \
    "It currently says:" \
    "  $(head -c 200 "$ANSWER")" \
    "" \
    "It has to name the Pod llmstats showed with a non-zero WAITING count -- the" \
    "full Pod name, as llmstats printed it. Read llmstats while the load is still" \
    "in flight; after it drains, every replica looks fine again."
fi

if [ -n "$FAST" ] && grep -q "$FAST" "$ANSWER" && ! grep -qi "idle" "$ANSWER"; then
  fail \
    "$ANSWER names '$FAST' as the replica in trouble. That is the other one." \
    "" \
    "chat-fast handles 8 requests at once; chat-slow handles 1 and queues the rest." \
    "Mention chat-fast only as the idle one, if at all."
fi

# And they must have identified the queue as the signal, not CPU or latency.
grep -qiE "wait|queue" "$ANSWER" || fail \
  "$ANSWER names the right Pod but not the signal that proves it." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "Latency tells you a user suffered; it does not tell you where the work piled" \
  "up. Record the number llmstats got from the model server itself -- the count" \
  "of requests that have arrived and have not started."

pass
