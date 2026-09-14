#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · The rule iptables cannot see"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

MARKER=/root/answers/.step3-done
NEXT_FAULT=5

[ -f "$MARKER" ] && pass

ANSWER=/root/answers/step3.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Say where the rule actually lives, then remove it:" \
  "  echo '<where the rule is>' > $ANSWER"

# "nft"/"nftables" is the finding; the table name is only visible via
# `nft list ruleset`, so either token proves they got past iptables -L.
grep -qiE "nft|nftables|inet lab" "$ANSWER" || fail \
  "$ANSWER does not say where the rule that is dropping traffic lives." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "iptables -L comes back clean and the traffic is still being dropped. That is" \
  "the finding: the two tools write to the same kernel subsystem but only one of" \
  "them shows you everything in it:" \
  "  netlab rtr iptables -L -v -n" \
  "  netlab rtr nft list ruleset"

# The rule has to be gone, not merely identified.
netlab rtr nft list ruleset 2>/dev/null | grep -q "table inet lab" && fail \
  "The nftables table is still there." \
  "" \
  "Finding it is most of the work, but the step is not done until it is gone:" \
  "  netlab rtr nft list ruleset" \
  "  netlab rtr nft delete table inet lab"

for _ in $(seq 1 6); do
  if netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/small.txt >/dev/null 2>&1; then
    touch "$MARKER"
    netlab fault "$NEXT_FAULT" >/dev/null 2>&1
    pass
  fi
  sleep 2
done

fail \
  "The nftables rule is gone, but the request still does not complete." \
  "" \
  "Something from an earlier step may have been put back, or another fault is" \
  "in play. Work down the path again:" \
  "  netlab rtr iptables -L -v -n" \
  "  netlab rtr nft list ruleset" \
  "  netlab srv ip route get 10.10.1.2" \
  "  netlab cli curl -m 6 -sS -o /dev/null -w '%{http_code}\\n' http://10.10.2.2:8080/small.txt"
