#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · One connection, two ends"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

PODIP=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$PODIP" ] && [ -n "$CLUSTERIP" ] || fail \
  "Could not read the web Pod's address or the Service's ClusterIP." \
  "" \
  "  kubectl get pods -l app=web -o wide" \
  "  kubectl get svc web"

CLIENT_CAP=/root/cap-client-side.txt
SERVER_CAP=/root/cap-server-side.txt
[ -f "$CLIENT_CAP" ] && [ -f "$SERVER_CAP" ] || fail \
  "Both captures are needed, and one or both is missing." \
  "" \
  "  $CLIENT_CAP:  $([ -f "$CLIENT_CAP" ] && echo present || echo MISSING)" \
  "  $SERVER_CAP:  $([ -f "$SERVER_CAP" ] && echo present || echo MISSING)" \
  "" \
  "Start both tcpdumps before the request, one per veth, so the same connection" \
  "is recorded at both ends."

CLIENT_SYN=$(grep 'Flags \[S\]' "$CLIENT_CAP" | head -1)
SERVER_SYN=$(grep 'Flags \[S\]' "$SERVER_CAP" | head -1)
[ -n "$CLIENT_SYN" ] && [ -n "$SERVER_SYN" ] || fail \
  "One of the captures has no SYN in it, so there is no connection opening to compare." \
  "" \
  "  client side: ${CLIENT_SYN:-<no SYN captured>}" \
  "  server side: ${SERVER_SYN:-<no SYN captured>}" \
  "" \
  "Both captures have to be running BEFORE the request is made -- a tcpdump" \
  "started afterwards misses the handshake entirely. Background both, sleep 1," \
  "then make the request."

# Same sequence number on both sides is the proof it is one connection seen
# twice, not two separate requests -- and it holds on either datapath.
CLIENT_SEQ=$(echo "$CLIENT_SYN" | grep -oE 'seq [0-9]+' | awk '{print $2}')
SERVER_SEQ=$(echo "$SERVER_SYN" | grep -oE 'seq [0-9]+' | awk '{print $2}')
[ -n "$CLIENT_SEQ" ] && [ "$CLIENT_SEQ" == "$SERVER_SEQ" ] || fail \
  "The two captures are not showing the same connection." \
  "" \
  "  client side seq: ${CLIENT_SEQ:-<none>}" \
  "  server side seq: ${SERVER_SEQ:-<none>}" \
  "" \
  "Matching sequence numbers are what prove you are looking at one packet at two" \
  "points on its path rather than at two different requests. Different numbers" \
  "mean the captures come from separate requests -- run both tcpdumps at once," \
  "then make a single request."

# Likewise the source: untranslated on both datapaths, which is what lets the
# backend see the caller's real identity.
CLIENT_SRC=$(echo "$CLIENT_SYN" | awk '{print $3}')
SERVER_SRC=$(echo "$SERVER_SYN" | awk '{print $3}')
[ -n "$CLIENT_SRC" ] && [ "$CLIENT_SRC" == "$SERVER_SRC" ] || fail \
  "The source address changed between the two captures." \
  "" \
  "  client side source: ${CLIENT_SRC:-<none>}" \
  "  server side source: ${SERVER_SRC:-<none>}" \
  "" \
  "Pod-to-Pod traffic inside the cluster is not masqueraded on either datapath," \
  "which is exactly why a NetworkPolicy on the backend can match the caller's" \
  "real identity. A changed source means the traffic came from outside the pod" \
  "network -- make the request from the client Pod, not from the node."

if iptables-save -t nat 2>/dev/null | grep -q "default/web"; then
  # kube-proxy: the destination is rewritten in flight, so the two captures
  # must disagree about it -- ClusterIP on the way out, Pod IP on arrival.
  echo "$CLIENT_SYN" | grep -q "> ${CLUSTERIP}\.80:" || fail \
    "This cluster runs kube-proxy, so the client-side capture should be addressed to the ClusterIP." \
    "" \
    "  client side: $CLIENT_SYN" \
    "  expected destination: ${CLUSTERIP}.80" \
    "" \
    "Make the request through the Service rather than straight to the Pod."

  echo "$SERVER_SYN" | grep -q "> ${PODIP}\.8080:" || fail \
    "The server-side capture is not addressed to the Pod (${PODIP}.8080)." \
    "" \
    "  server side: $SERVER_SYN" \
    "" \
    "That is the one translation this connection goes through, and it is visible" \
    "only by capturing on web's own veth. Check the interface:" \
    "  head -1 $SERVER_CAP"
else
  # eBPF socket LB: translation happened before the packet existed, so both
  # ends must show the Pod IP and agree completely on the destination.
  echo "$CLIENT_SYN" | grep -q "> ${PODIP}\.8080:" || fail \
    "This cluster rewrites the destination inside connect(), so the client-side capture should already show ${PODIP}.8080." \
    "" \
    "  client side: $CLIENT_SYN" \
    "" \
    "If the ClusterIP is there instead, the capture predates the request or comes" \
    "from somewhere other than client's veth:" \
    "  head -1 $CLIENT_CAP"

  echo "$SERVER_SYN" | grep -q "> ${PODIP}\.8080:" || fail \
    "The server-side capture is not addressed to ${PODIP}.8080." \
    "" \
    "  server side: $SERVER_SYN" \
    "" \
    "Check which interface it was taken on -- it has to be web's own veth:" \
    "  head -1 $SERVER_CAP"

  CLIENT_DST=$(echo "$CLIENT_SYN" | awk '{print $5}')
  SERVER_DST=$(echo "$SERVER_SYN" | awk '{print $5}')
  [ "$CLIENT_DST" == "$SERVER_DST" ] || fail \
    "The two captures disagree about the destination, and on this datapath they cannot." \
    "" \
    "  client side destination: $CLIENT_DST" \
    "  server side destination: $SERVER_DST" \
    "" \
    "There is no in-flight translation here, so the two captures should be" \
    "identical. A difference means they are not the same connection after all."
fi

pass
