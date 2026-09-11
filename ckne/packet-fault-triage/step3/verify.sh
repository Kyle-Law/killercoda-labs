#!/bin/bash

MARKER=/root/answers/.step3-done
NEXT_FAULT=5

[ -f "$MARKER" ] && exit 0

ANSWER=/root/answers/step3.txt
[ -f "$ANSWER" ] || exit 1

# "nft"/"nftables" is the finding; the table name is only visible via
# `nft list ruleset`, so either token proves they got past iptables -L.
grep -qiE "nft|nftables|inet lab" "$ANSWER" || exit 1

# The rule has to be gone, not merely identified.
netlab rtr nft list ruleset 2>/dev/null | grep -q "table inet lab" && exit 1

for _ in $(seq 1 6); do
  if netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/small.txt >/dev/null 2>&1; then
    touch "$MARKER"
    netlab fault "$NEXT_FAULT" >/dev/null 2>&1
    exit 0
  fi
  sleep 2
done

exit 1
