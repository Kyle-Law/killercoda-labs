#!/bin/bash

# both teams must be capped
for ns in team-a team-b; do
  HARD=$(kubectl get resourcequota gpu-quota -n "$ns" -o jsonpath='{.spec.hard.requests\.nvidia\.com/gpu}' 2>/dev/null)
  [ "$HARD" == "2" ] || exit 1
done

# the over-quota attempt must have been REJECTED at admission, which is the
# whole point of the step - a Pending pod would mean quota never applied
grep -qi "exceeded quota" /root/quota-error 2>/dev/null || exit 1

# and no Pod may exist for that rejected request
if kubectl get pod greedy -n team-a >/dev/null 2>&1; then exit 1; fi

exit 0
