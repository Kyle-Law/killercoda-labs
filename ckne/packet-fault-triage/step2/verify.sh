#!/bin/bash

MARKER=/root/answers/.step2-done
NEXT_FAULT=8

[ -f "$MARKER" ] && exit 0

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || exit 1

# The finding is about the return path, established with `ip route get` (or by
# naming the missing route). Either phrasing proves they looked at routing on
# the server rather than continuing to stare at the client.
grep -qiE "route|unreachable" "$ANSWER" || exit 1

# The server must be able to reach the client again, and the path must work.
for _ in $(seq 1 6); do
  if netlab srv ip route get 10.10.1.2 >/dev/null 2>&1 \
     && netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/small.txt >/dev/null 2>&1; then
    touch "$MARKER"
    netlab fault "$NEXT_FAULT" >/dev/null 2>&1
    exit 0
  fi
  sleep 2
done

exit 1
