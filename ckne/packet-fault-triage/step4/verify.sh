#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · Only the big ones fail"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ANSWER=/root/answers/step4.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Write the MTU of the narrow hop, then fix the path so a large transfer" \
  "completes:" \
  "  echo '<mtu>' > $ANSWER"

# 1400 is only obtainable by comparing MTUs across the hops.
grep -q "1400" "$ANSWER" || fail \
  "$ANSWER does not give the MTU of the narrow link." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "A small request succeeds and a large one hangs, which means the packets that" \
  "fail are the ones that do not fit. Compare the MTU at every hop -- the number" \
  "wanted here is the smallest one on the path:" \
  "  netlab cli ip link" \
  "  netlab rtr ip link" \
  "  netlab srv ip link"

# The large transfer is the whole point -- the small one succeeded even while
# the fault was in place, so checking it alone would prove nothing. Either
# accepted fix (raise the MTU, or stop filtering the ICMP) satisfies this.
for _ in $(seq 1 4); do
  SIZE=$(netlab cli curl -m 20 -sS -o /dev/null -w '%{size_download}' \
    http://10.10.2.2:8080/big.bin 2>/dev/null)
  [ "$SIZE" == "2000000" ] && pass
  sleep 2
done

fail \
  "You have the MTU, but the large transfer still does not finish." \
  "" \
  "  downloaded ${SIZE:-0} bytes of 2000000" \
  "" \
  "Two things have to be true for a path like this to work, and either one is" \
  "enough to fix it: the narrow hop is wide enough for the packets being sent," \
  "or the sender is told to send smaller ones. The second is what 'fragmentation" \
  "needed' ICMP exists to say -- and a rule dropping it turns a normal narrow" \
  "link into a black hole that only swallows large packets:" \
  "  netlab rtr ip link" \
  "  netlab rtr iptables -L -v -n | grep -i icmp" \
  "  netlab cli curl -m 20 -sS -o /dev/null -w '%{size_download}\\n' http://10.10.2.2:8080/big.bin"
