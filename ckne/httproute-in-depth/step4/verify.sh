#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · A route into a namespace that didn't ask for it"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

kubectl get httproute cross-ns-route -o jsonpath='{.metadata.name}' >/dev/null 2>&1 || fail \
  "There is no HTTPRoute named 'cross-ns-route' in the default namespace." \
  "" \
  "The route lives beside the Gateway, in default, and points at a Service in" \
  "team-b. That is the arrangement the two namespace boundaries apply to."

kubectl -n team-b get httproute cross-ns-route >/dev/null 2>&1 && fail \
  "'cross-ns-route' also exists in the team-b namespace." \
  "" \
  "Moving the route into team-b sidesteps the question instead of answering it." \
  "Leave it in default, where it has to cross a namespace boundary to reach the" \
  "backend:" \
  "  kubectl -n team-b delete httproute cross-ns-route"

REF=$(kubectl get httproute cross-ns-route -o jsonpath='{.spec.rules[0].backendRefs[0].namespace}' 2>/dev/null)
[ "$REF" == "team-b" ] || fail \
  "The route's backendRef names namespace '${REF:-<unset>}', not 'team-b'." \
  "" \
  "A backendRef with no namespace means the route's own -- which is default, so" \
  "nothing crosses anything:" \
  "  kubectl get httproute cross-ns-route -o jsonpath='{.spec.rules[0].backendRefs}' | tr '{' '\\n'"

kubectl -n team-b get referencegrant allow-default-httproutes >/dev/null 2>&1 || fail \
  "There is no ReferenceGrant named 'allow-default-httproutes' in team-b." \
  "" \
  "These are two different boundaries, and this is the second one:" \
  "  - allowedRoutes, on the LISTENER, says which namespaces may attach routes" \
  "  - a ReferenceGrant, in the TARGET namespace, permits a backendRef into it" \
  "" \
  "The grant has to be created by team-b, naming the kind and namespace it" \
  "accepts references from -- consent travels in the direction of the reference."

for _ in $(seq 1 24); do
  RESOLVED=$(kubectl get httproute cross-ns-route \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
  [ "$RESOLVED" == "True" ] || { R="resolved"; sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { R="gwip"; sleep 5; continue; }

  ANSWER=$(kubectl exec client -- wget -qO- -T5 --header="Host: team-b.example.com" "http://$GWIP:80/hostname" 2>/dev/null)
  TEAMB_POD=$(kubectl -n team-b get pod -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  [ -n "$ANSWER" ] && [ "$ANSWER" == "$TEAMB_POD" ] && pass
  R="traffic"
  sleep 5
done

case "$R" in
  resolved) fail \
    "The ReferenceGrant exists, but the route's references still do not resolve (ResolvedRefs=${RESOLVED:-<none>})." \
    "" \
    "The reason names exactly what it refused -- usually the grant's 'from' kind" \
    "or namespace, or its 'to' kind, not matching what the route is asking for:" \
    "  kubectl get httproute cross-ns-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\\n'" \
    "  kubectl -n team-b get referencegrant allow-default-httproutes -o yaml" ;;
  gwip) fail \
    "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
    "" \
    "  kubectl -n envoy-gateway-system get pods,svc" ;;
  *) fail \
    "References resolve, but the request did not come back from a team-b Pod." \
    "" \
    "  response:        ${ANSWER:-<nothing>}" \
    "  team-b web Pod:  ${TEAMB_POD:-<none>}" \
    "" \
    "That is the other boundary: the listener's allowedRoutes decides whether a" \
    "route from this namespace may attach at all, and a route that never attached" \
    "produces nothing no matter how the backendRef is permitted:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.spec.listeners}' | tr '{' '\\n'" \
    "  kubectl get httproute cross-ns-route -o yaml | tail -20" ;;
esac
