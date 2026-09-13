#!/bin/bash

ANSWER=/root/answers/step4.txt
[ -f "$ANSWER" ] || exit 1

# The metric itself -- accept the Prometheus name in either punctuation, since
# an HPA via prometheus-adapter sees it with underscores.
grep -qE "num_requests_waiting" "$ANSWER" || exit 1

# And the observation that rules CPU out. Naming the metric without knowing
# why CPU fails is the half-answer this step exists to prevent.
grep -qiE "cpu" "$ANSWER" || exit 1

# The workload must still be intact for the reading to have meant anything.
kubectl get deploy chat-slow >/dev/null 2>&1 || exit 1

exit 0
