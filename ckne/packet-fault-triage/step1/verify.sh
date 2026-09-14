#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · Hang or refuse: the first branch"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

MARKER=/root/answers/.step1-done
NEXT_FAULT=4

# Already passed once: Killercoda re-runs verification whenever Check is
# pressed, and injecting the next fault twice would break the following step.
[ -f "$MARKER" ] && pass

ANSWER=/root/answers/step1.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Name the chain the packets are being dropped in, then remove the rule:" \
  "  echo '<chain>' > $ANSWER"

# The chain name is the finding this step is actually about -- FORWARD rather
# than INPUT -- and it is only obtainable by reading the counters.
grep -qi "forward" "$ANSWER" || fail \
  "$ANSWER does not name the chain the packets are dying in." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "A drop that hangs rather than refuses happened on the way THROUGH a box, not" \
  "on the way INTO it -- and the counters say which chain, because only the one" \
  "actually matching is incrementing:" \
  "  netlab rtr iptables -L -v -n" \
  "  netlab rtr iptables -Z   # zero them, retry the request, look again"

# Retried: a probe issued immediately after the offending rule is removed can
# still fail once, and failing the learner for that would be wrong.
for _ in $(seq 1 6); do
  if netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/small.txt >/dev/null 2>&1; then
    touch "$MARKER"
    netlab fault "$NEXT_FAULT" >/dev/null 2>&1
    pass
  fi
  sleep 2
done

fail \
  "You named the right chain, but the request from cli still does not complete." \
  "" \
  "Identifying the rule is not the same as removing it. Delete it and try the" \
  "request by hand:" \
  "  netlab rtr iptables -L FORWARD -v -n --line-numbers" \
  "  netlab rtr iptables -D FORWARD <line>" \
  "  netlab cli curl -m 6 -sS -o /dev/null -w '%{http_code}\\n' http://10.10.2.2:8080/small.txt"
