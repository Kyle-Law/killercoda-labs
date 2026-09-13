#!/bin/bash

ANSWER=/root/answers/step1.txt
[ -f "$ANSWER" ] || exit 1
CLAIM=$(tr -dc '0-9' < "$ANSWER")
[ -n "$CLAIM" ] || exit 1

# Read the real identity straight from Cilium rather than trusting the answer,
# so a guessed number cannot pass.
for _ in $(seq 1 12); do
  REAL=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    cilium-dbg endpoint list 2>/dev/null | awk '/k8s:app=api/{print $4; exit}')
  [ -n "$REAL" ] && break
  sleep 5
done
[ -n "$REAL" ] || exit 1

[ "$CLAIM" == "$REAL" ] && exit 0
exit 1
