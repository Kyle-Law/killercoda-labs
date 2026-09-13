#!/bin/bash

kubectl get netpol api-deny >/dev/null 2>&1 || exit 1

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || exit 1
grep -qi "policy denied" "$ANSWER" || exit 1

# The drop must be real and observable, not just asserted in the file.
for _ in $(seq 1 12); do
  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    hubble observe --since 120s --to-pod api --verdict DROPPED 2>/dev/null \
    | grep -q "Policy denied" && exit 0
  sleep 5
done

exit 1
