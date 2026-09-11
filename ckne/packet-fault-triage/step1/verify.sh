#!/bin/bash

MARKER=/root/answers/.step1-done
NEXT_FAULT=4

# Already passed once: Killercoda re-runs verification whenever Check is
# pressed, and injecting the next fault twice would break the following step.
[ -f "$MARKER" ] && exit 0

ANSWER=/root/answers/step1.txt
[ -f "$ANSWER" ] || exit 1

# The chain name is the finding this step is actually about -- FORWARD rather
# than INPUT -- and it is only obtainable by reading the counters.
grep -qi "forward" "$ANSWER" || exit 1

# Retried: a probe issued immediately after the offending rule is removed can
# still fail once, and failing the learner for that would be wrong.
for _ in $(seq 1 6); do
  if netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/small.txt >/dev/null 2>&1; then
    touch "$MARKER"
    netlab fault "$NEXT_FAULT" >/dev/null 2>&1
    exit 0
  fi
  sleep 2
done

exit 1
