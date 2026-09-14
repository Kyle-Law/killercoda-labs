#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · Where the decision is made, and what it costs"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

# The L7 policy must be back in place at the end of the step.
kubectl get ciliumnetworkpolicy api-l7 >/dev/null 2>&1 || fail \
  "The CiliumNetworkPolicy 'api-l7' is not there." \
  "" \
  "Measuring what the redirect costs means comparing with it off and with it on," \
  "and the step ends with it on. Put it back:" \
  "  kubectl get ciliumnetworkpolicy"

# And the proxy redirect it implies must actually be programmed -- that is the
# observation this step is about, not merely that the policy object exists.
for _ in $(seq 1 18); do
  STATUS=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    cilium-dbg status --verbose 2>/dev/null)
  echo "$STATUS" | grep -q 'cilium-http-ingress' || { R="proxy"; sleep 5; continue; }

  WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -n "$WEBPOD" ] || { R="webpod"; sleep 5; continue; }

  OK=$(kubectl exec "$WEBPOD" -- curl -s -m 6 -o /dev/null -w '%{http_code}' http://api/hostname 2>/dev/null)
  [ "$OK" == "200" ] && pass
  R="request"
  sleep 5
done

case "$R" in
  proxy) fail \
    "The policy exists, but no HTTP proxy redirect is programmed for it." \
    "" \
    "An L7 rule is not enforced in the datapath -- the agent programs a redirect" \
    "that sends matching traffic through an Envoy listener first, and that is" \
    "what the step is measuring the cost of. It appears in the agent's own" \
    "status under Proxy redirection:" \
    "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \\" \
    "    cilium-dbg status --verbose | grep -A5 Proxy" \
    "" \
    "If it never appears, the policy may be accepted but selecting nothing:" \
    "  kubectl get ciliumnetworkpolicy api-l7 -o yaml" ;;
  webpod) fail \
    "No running Pod with label app=web to make the request from." \
    "" \
    "  kubectl get pods -l app=web" ;;
  *) fail \
    "The redirect is programmed, but the allowed request is not succeeding (got ${OK:-000})." \
    "" \
    "GET /hostname has to still come back 200 with the policy on -- enforcement" \
    "that refuses the legitimate request too is not enforcement, it is an outage:" \
    "  kubectl get ciliumnetworkpolicy api-l7 -o yaml" \
    "  kubectl get netpol,ciliumnetworkpolicy" ;;
esac
