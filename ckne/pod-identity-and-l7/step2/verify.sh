#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · A rule about methods and paths"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

CNP=$(kubectl get ciliumnetworkpolicy api-l7 -o json 2>/dev/null)
[ -n "$CNP" ] || fail \
  "There is no CiliumNetworkPolicy named 'api-l7'." \
  "" \
  "Native NetworkPolicy cannot express a method or a path, so this one has to be" \
  "a CiliumNetworkPolicy with an http rule under toPorts.rules."

echo "$CNP" | grep -q '"http"' || fail \
  "'api-l7' has no http rules in it." \
  "" \
  "Without toPorts.rules.http it is just another L4 policy under a different" \
  "kind, and enforces nothing about methods or paths:" \
  "  kubectl get ciliumnetworkpolicy api-l7 -o yaml"

# The broad L4 allow must be gone. Left in place it unions with the L7 rule
# and permits everything on the port, which is the trap this step teaches.
kubectl get netpol api-l4 >/dev/null 2>&1 && fail \
  "'api-l4' from step 1 is still in force, and it defeats the L7 rule." \
  "" \
  "This is the trap the step is about. Policies are ALLOW-only and additive:" \
  "they union, they never restrict each other. A POST that the L7 rule refuses" \
  "still satisfies the broad L4 allow, and one match is enough -- so the L7" \
  "policy is accepted, loaded, its Envoy redirect programmed, and has no visible" \
  "effect whatsoever." \
  "" \
  "  kubectl delete netpol api-l4" \
  "" \
  "Then try the POST again and watch the verdict change."

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || fail \
  "No running Pod with label app=web to make the requests from." \
  "" \
  "  kubectl get pods -l app=web"

# All three verdicts must hold at once: the allowed request succeeds, and the
# other two are REFUSED (403) rather than dropped (000) -- a 000 would mean an
# L3/L4 block, not L7 enforcement.
for _ in $(seq 1 18); do
  OK=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  BADPATH=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/ 2>/dev/null)
  BADMETHOD=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -X POST --data '' -w '%{http_code}' http://api/hostname 2>/dev/null)

  if [ "$OK" == "200" ] && [ "$BADPATH" == "403" ] && [ "$BADMETHOD" == "403" ]; then
    pass
  fi
  sleep 5
done

fail \
  "The L7 policy is in place, but the three verdicts are not what enforcement looks like." \
  "" \
  "  GET  /hostname  ->  ${OK:-000}        (expected 200)" \
  "  GET  /          ->  ${BADPATH:-000}   (expected 403)" \
  "  POST /hostname  ->  ${BADMETHOD:-000} (expected 403)" \
  "" \
  "403 and 000 mean different things, and the difference is the point: 403 is a" \
  "proxy refusing the request after reading it, 000 is the connection never" \
  "being allowed at all. A 000 where a 403 belongs means the rule is blocking at" \
  "L3/L4 -- check the port and the endpoint selector:" \
  "  kubectl get ciliumnetworkpolicy api-l7 -o yaml" \
  "" \
  "200 where a 403 belongs means something else is still allowing the traffic:" \
  "  kubectl get netpol,ciliumnetworkpolicy"
