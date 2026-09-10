#!/bin/bash

PODIP=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$PODIP" ] && [ -n "$CLUSTERIP" ] || exit 1

CLIENT_CAP=/root/cap-client-side.txt
SERVER_CAP=/root/cap-server-side.txt
[ -f "$CLIENT_CAP" ] && [ -f "$SERVER_CAP" ] || exit 1

CLIENT_SYN=$(grep 'Flags \[S\]' "$CLIENT_CAP" | head -1)
SERVER_SYN=$(grep 'Flags \[S\]' "$SERVER_CAP" | head -1)
[ -n "$CLIENT_SYN" ] && [ -n "$SERVER_SYN" ] || exit 1

# The client-side capture is the request as client actually sent it: to the
# ClusterIP, never the Pod IP.
echo "$CLIENT_SYN" | grep -q "> ${CLUSTERIP}\.80:" || exit 1
echo "$CLIENT_SYN" | grep -q "$PODIP" && exit 1

# The server-side capture is the same connection after DNAT: to the Pod IP.
echo "$SERVER_SYN" | grep -q "> ${PODIP}\.8080:" || exit 1

# Same TCP sequence number on both sides is the proof it's one connection,
# not two separately-captured requests.
CLIENT_SEQ=$(echo "$CLIENT_SYN" | grep -oE 'seq [0-9]+' | awk '{print $2}')
SERVER_SEQ=$(echo "$SERVER_SYN" | grep -oE 'seq [0-9]+' | awk '{print $2}')
[ -n "$CLIENT_SEQ" ] && [ "$CLIENT_SEQ" == "$SERVER_SEQ" ] || exit 1

# And the same source address and port on both sides -- proof the source was
# never translated, only the destination.
CLIENT_SRC=$(echo "$CLIENT_SYN" | awk '{print $2}')
SERVER_SRC=$(echo "$SERVER_SYN" | awk '{print $2}')
[ -n "$CLIENT_SRC" ] && [ "$CLIENT_SRC" == "$SERVER_SRC" ] || exit 1

exit 0
