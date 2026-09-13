#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · The IP-based rule that matches nothing"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The step must end on the label-based rule, not the ipBlock one.
POL=$(kubectl get netpol api-l4 -o json 2>/dev/null)
[ -n "$POL" ] || fail \
  "There is no NetworkPolicy named 'api-l4'." \
  "" \
  "This step rebuilds it twice -- once with an ipBlock naming web's current" \
  "address, and once with a podSelector -- and ends on the one that works."

echo "$POL" | grep -q '"ipBlock"' && fail \
  "'api-l4' still selects the caller by ipBlock." \
  "" \
  "That is the version that matches nothing, even with the correct current" \
  "address in it: Cilium resolves in-cluster Pod traffic to a label-derived" \
  "security identity, while a CIDR selector resolves to a different one, so the" \
  "two never meet. Change only the selector -- every other field identical -- and" \
  "the same traffic is allowed:" \
  "  kubectl get netpol api-l4 -o yaml"

echo "$POL" | grep -q '"app": *"web"' || fail \
  "'api-l4' does not select the caller by label." \
  "" \
  "The working version names web with a podSelector rather than an address:" \
  "  kubectl get netpol api-l4 -o yaml"

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || fail \
  "No running Pod with label app=web to make the request from." \
  "" \
  "  kubectl get pods -l app=web"

# Traffic must flow again under the label selector.
for _ in $(seq 1 18); do
  OK=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  [ "$OK" == "200" ] && pass
  sleep 5
done

fail \
  "The policy selects web by label, but the request is still not getting through (got ${OK:-000})." \
  "" \
  "000 means the connection was refused at L3/L4, so something is still not" \
  "matching. Check the labels the policy asks for against the ones the Pod" \
  "actually has, and that the port is the container's:" \
  "  kubectl get pod -l app=web --show-labels" \
  "  kubectl get netpol api-l4 -o yaml" \
  "" \
  "403 means the L7 policy from step 2 is refusing this path -- it should allow" \
  "GET /hostname:" \
  "  kubectl get ciliumnetworkpolicy api-l7 -o yaml"
