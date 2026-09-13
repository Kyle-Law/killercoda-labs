#!/bin/bash

# The route has to be serving both replicas, or none of this step happened.
BACKEND=$(kubectl get httproute chat-route -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)
[ "$BACKEND" == "chat" ] || exit 1

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || exit 1

# The finding is that the SLOW replica is the backed-up one. Naming the fast
# replica instead would be the opposite conclusion, so check both ways.
SLOW=$(kubectl get pod -l speed=slow -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
FAST=$(kubectl get pod -l speed=fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$SLOW" ] || exit 1

grep -q "$SLOW" "$ANSWER" || grep -qi "chat-slow" "$ANSWER" || exit 1
[ -n "$FAST" ] && grep -q "$FAST" "$ANSWER" && ! grep -qi "idle" "$ANSWER" && exit 1

# And they must have identified the queue as the signal, not CPU or latency.
grep -qiE "wait|queue" "$ANSWER" || exit 1

exit 0
