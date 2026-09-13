#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · One port, one verdict"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

POL=$(kubectl get netpol api-l4 -o json 2>/dev/null)
[ -n "$POL" ] || fail \
  "There is no NetworkPolicy named 'api-l4'." \
  "" \
  "It should select api, allow ingress from web, and name the container port."

echo "$POL" | grep -q '"app": *"api"' || fail \
  "'api-l4' does not select app=api." \
  "" \
  "The podSelector decides what the policy protects:" \
  "  kubectl get netpol api-l4 -o yaml"

echo "$POL" | grep -q '"app": *"web"' || fail \
  "'api-l4' does not allow app=web." \
  "" \
  "Without an ingress rule naming web, this is a default-deny and the requests" \
  "below will never succeed:" \
  "  kubectl get netpol api-l4 -o yaml"

echo "$POL" | grep -q '8080' || fail \
  "'api-l4' does not name port 8080." \
  "" \
  "A NetworkPolicy matches the container's port, not the Service's:" \
  "  kubectl get pod -l app=api -o jsonpath='{.items[0].spec.containers[0].ports}'"

# No L7 policy yet -- that is step 2. Passing this step with one already in
# place would skip the limit the step exists to demonstrate.
kubectl get ciliumnetworkpolicy api-l7 >/dev/null 2>&1 && fail \
  "A CiliumNetworkPolicy 'api-l7' already exists." \
  "" \
  "This step is about what a native NetworkPolicy can and cannot express, and" \
  "an L7 policy sitting alongside it hides exactly that. Remove it -- step 2 is" \
  "where it belongs:" \
  "  kubectl delete ciliumnetworkpolicy api-l7"

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || fail \
  "No running Pod with label app=web to make the requests from." \
  "" \
  "  kubectl get pods -l app=web"

# The L4 policy must genuinely allow the traffic -- including the POST it
# cannot distinguish, which is the whole point.
for _ in $(seq 1 12); do
  G=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  P=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -X POST --data '' -w '%{http_code}' http://api/ 2>/dev/null)
  [ "$G" == "200" ] && [ "$P" == "200" ] && pass
  sleep 5
done

fail \
  "The policy exists, but the two requests did not both come back 200." \
  "" \
  "  GET  /hostname  ->  ${G:-000}" \
  "  POST /          ->  ${P:-000}" \
  "" \
  "Both are supposed to succeed: that is the finding. A NetworkPolicy decides" \
  "per (identity, port) and has no way to tell one HTTP request on that port" \
  "from another, so allowing web to reach 8080 allows every method and path." \
  "" \
  "000 means nothing answered at all -- the connection was dropped at L3/L4," \
  "so the policy is not permitting web the way you think:" \
  "  kubectl get netpol api-l4 -o yaml" \
  "  kubectl get pod -l app=web --show-labels"
