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

# Same sequence number on both sides is the proof it is one connection seen
# twice, not two separate requests -- and it holds on either datapath.
CLIENT_SEQ=$(echo "$CLIENT_SYN" | grep -oE 'seq [0-9]+' | awk '{print $2}')
SERVER_SEQ=$(echo "$SERVER_SYN" | grep -oE 'seq [0-9]+' | awk '{print $2}')
[ -n "$CLIENT_SEQ" ] && [ "$CLIENT_SEQ" == "$SERVER_SEQ" ] || exit 1

# Likewise the source: untranslated on both datapaths, which is what lets the
# backend see the caller's real identity.
CLIENT_SRC=$(echo "$CLIENT_SYN" | awk '{print $3}')
SERVER_SRC=$(echo "$SERVER_SYN" | awk '{print $3}')
[ -n "$CLIENT_SRC" ] && [ "$CLIENT_SRC" == "$SERVER_SRC" ] || exit 1

if iptables-save -t nat 2>/dev/null | grep -q "default/web"; then
  # kube-proxy: the destination is rewritten in flight, so the two captures
  # must disagree about it -- ClusterIP on the way out, Pod IP on arrival.
  echo "$CLIENT_SYN" | grep -q "> ${CLUSTERIP}\.80:" || exit 1
  echo "$SERVER_SYN" | grep -q "> ${PODIP}\.8080:" || exit 1
else
  # eBPF socket LB: translation happened before the packet existed, so both
  # ends must show the Pod IP and agree completely on the destination.
  echo "$CLIENT_SYN" | grep -q "> ${PODIP}\.8080:" || exit 1
  echo "$SERVER_SYN" | grep -q "> ${PODIP}\.8080:" || exit 1

  CLIENT_DST=$(echo "$CLIENT_SYN" | awk '{print $5}')
  SERVER_DST=$(echo "$SERVER_SYN" | awk '{print $5}')
  [ "$CLIENT_DST" == "$SERVER_DST" ] || exit 1
fi

exit 0
