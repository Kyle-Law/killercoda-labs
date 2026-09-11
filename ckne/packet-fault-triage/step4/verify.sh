#!/bin/bash

ANSWER=/root/answers/step4.txt
[ -f "$ANSWER" ] || exit 1

# 1400 is only obtainable by comparing MTUs across the hops.
grep -q "1400" "$ANSWER" || exit 1

# The large transfer is the whole point -- the small one succeeded even while
# the fault was in place, so checking it alone would prove nothing. Either
# accepted fix (raise the MTU, or stop filtering the ICMP) satisfies this.
for _ in $(seq 1 4); do
  SIZE=$(netlab cli curl -m 20 -sS -o /dev/null -w '%{size_download}' \
    http://10.10.2.2:8080/big.bin 2>/dev/null)
  [ "$SIZE" == "2000000" ] && exit 0
  sleep 2
done

exit 1
