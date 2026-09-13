#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · One Gateway, two listeners, one route"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 24); do
  LISTENERS=$(kubectl get gateway web-gateway -o jsonpath='{.spec.listeners[*].name}' 2>/dev/null)
  echo "$LISTENERS" | grep -qw public && echo "$LISTENERS" | grep -qw internal || { R="names"; sleep 5; continue; }

  PUBLIC_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="public")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  INTERNAL_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="internal")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$PUBLIC_PROG" == "True" ] && [ "$INTERNAL_PROG" == "True" ] || { R="programmed"; sleep 5; continue; }

  # The route must be attached to the public listener specifically, not to
  # the Gateway as a whole -- sectionName is the point of this step.
  SECTION=$(kubectl get httproute web-route \
    -o jsonpath='{.spec.parentRefs[0].sectionName}' 2>/dev/null)
  [ "$SECTION" == "public" ] || { R="section"; sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { R="gwip"; sleep 5; continue; }

  PUBLIC_OK=$(kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname" 2>/dev/null)
  INTERNAL_CODE=$(kubectl exec client -- wget -S -O /dev/null -T5 --header="Host: web.example.com" "http://$GWIP:8080/hostname" 2>&1 \
    | grep -oE 'HTTP/[0-9.]+ [0-9]+' | awk '{print $2}' | head -1)

  # Reachable where attached, and specifically NOT reachable on the listener
  # it was never attached to -- a route that (wrongly) attached to both
  # listeners would pass the first check and fail this one.
  echo "$PUBLIC_OK" | grep -q "^web-" && [ "$INTERNAL_CODE" == "404" ] && pass
  R="traffic"
  sleep 5
done

case "$R" in
  names) fail \
    "The Gateway does not have both listeners." \
    "" \
    "  listeners found: ${LISTENERS:-<none>}" \
    "  expected:        public and internal" \
    "" \
    "  kubectl get gateway web-gateway -o yaml" ;;
  programmed) fail \
    "The listeners are not both Programmed (public=${PUBLIC_PROG:-<none>}, internal=${INTERNAL_PROG:-<none>})." \
    "" \
    "Each listener reports its own condition, and two listeners on the same port" \
    "with the same hostname will conflict rather than coexist:" \
    "  kubectl get gateway web-gateway -o jsonpath='{.status.listeners}' | tr '{' '\\n'" ;;
  section) fail \
    "'web-route' attaches to sectionName '${SECTION:-<unset>}', not 'public'." \
    "" \
    "A parentRef with no sectionName attaches the route to every listener the" \
    "Gateway has -- which is exactly what this step is distinguishing from" \
    "attaching to one:" \
    "  kubectl get httproute web-route -o jsonpath='{.spec.parentRefs}' | tr '{' '\\n'" ;;
  gwip) fail \
    "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
    "" \
    "  kubectl -n envoy-gateway-system get pods,svc" ;;
  *) fail \
    "The route is attached to 'public', but traffic does not behave as it should." \
    "" \
    "  port 80 (public):     ${PUBLIC_OK:-<nothing>}   (expected a web- Pod name)" \
    "  port 8080 (internal): HTTP ${INTERNAL_CODE:-<no response>}   (expected 404)" \
    "" \
    "A 404 on 8080 is the point: the listener is up and answering, and has no" \
    "route attached to it. Anything else on 8080 means the route attached to both" \
    "listeners after all. Nothing on 80 means the route is attached but not" \
    "matching -- check its hostnames against the listener's:" \
    "  kubectl get httproute web-route -o yaml | tail -25" ;;
esac
