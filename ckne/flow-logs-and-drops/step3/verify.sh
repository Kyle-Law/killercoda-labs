#!/bin/bash

# The deny must be gone, or "what is talking to this" has no traffic to see.
kubectl get netpol api-deny >/dev/null 2>&1 && exit 1

ANSWER=/root/answers/step3.txt
[ -f "$ANSWER" ] || exit 1
grep -qi "scanner" "$ANSWER" || exit 1

# Naming web instead of, or as well as, the scanner is the wrong finding --
# web is the legitimate caller.
grep -qiE "^web|web is (the )?unauthoris|web.*should not" "$ANSWER" && exit 1

exit 0
