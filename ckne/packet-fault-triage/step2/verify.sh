#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · One-ended captures lie"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

MARKER=/root/answers/.step2-done
NEXT_FAULT=8

[ -f "$MARKER" ] && pass

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Say what is wrong on the server side, then fix it:" \
  "  echo '<what is missing>' > $ANSWER"

# The finding is about the return path, established with `ip route get` (or by
# naming the missing route). Either phrasing proves they looked at routing on
# the server rather than continuing to stare at the client.
grep -qiE "route|unreachable" "$ANSWER" || fail \
  "$ANSWER does not describe what is wrong with the return path." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "A capture at the client shows SYNs leaving and nothing coming back, which" \
  "looks identical to a drop on the way out. Capture at the server instead: the" \
  "SYNs are arriving. Then ask the server how it would answer:" \
  "  netlab srv ip route get 10.10.1.2"

# The server must be able to reach the client again, and the path must work.
for _ in $(seq 1 6); do
  if netlab srv ip route get 10.10.1.2 >/dev/null 2>&1 \
     && netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/small.txt >/dev/null 2>&1; then
    touch "$MARKER"
    netlab fault "$NEXT_FAULT" >/dev/null 2>&1
    pass
  fi
  sleep 2
done

ROUTE=$(netlab srv ip route get 10.10.1.2 2>&1 | head -1)
fail \
  "The diagnosis is right, but the return path still does not work." \
  "" \
  "  netlab srv ip route get 10.10.1.2" \
  "    -> ${ROUTE:-<no output>}" \
  "" \
  "The server needs a route back to the client's network via the router, and the" \
  "request has to complete once it has one:" \
  "  netlab srv ip route add 10.10.1.0/24 via 10.10.2.1" \
  "  netlab cli curl -m 6 -sS -o /dev/null -w '%{http_code}\\n' http://10.10.2.2:8080/small.txt"
