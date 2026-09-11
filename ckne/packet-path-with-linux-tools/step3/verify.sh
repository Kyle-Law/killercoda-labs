#!/bin/bash

PODIP=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$PODIP" ] && [ -n "$CLUSTERIP" ] || exit 1

CAP=/root/cap-service.txt
EVIDENCE=/root/svc-translation.txt
[ -f "$CAP" ] && [ -f "$EVIDENCE" ] || exit 1

# The capture has to be on client's veth -- that is what makes the address in
# it meaningful either way.
CVETH=$(podveth client 2>/dev/null)
[ -n "$CVETH" ] && grep -q "listening on $CVETH," "$CAP" || exit 1

# Which datapath is this cluster actually running? Decided from the cluster
# itself rather than from what the learner claims, so each branch below is
# checked against the thing that is really true here.
if iptables-save -t nat 2>/dev/null | grep -q "default/web"; then
  # kube-proxy: translation happens in the forwarding path, so a capture on
  # the client's own veth must still show the ClusterIP and never the Pod IP.
  grep -qE "IP [0-9.]+\.[0-9]+ > ${CLUSTERIP}\.80: .*HTTP: GET" "$CAP" || exit 1
  grep -q "$PODIP" "$CAP" && exit 1

  # ...and the saved evidence must be the real DNAT rule for this Service.
  grep -q "DNAT" "$EVIDENCE" || exit 1
  grep -q "default/web" "$EVIDENCE" || exit 1
  grep -q "$PODIP" "$EVIDENCE" || exit 1
else
  # eBPF socket LB: the rewrite happened inside connect(), before a packet
  # existed, so the wire shows the Pod IP and target port from the very first
  # SYN -- and the ClusterIP never appears on it at all.
  grep -qE "> ${PODIP}\.8080: " "$CAP" || exit 1
  grep -q "$CLUSTERIP" "$CAP" && exit 1

  # The evidence has to come from the map, and name both ends of the mapping.
  grep -q "$CLUSTERIP" "$EVIDENCE" || exit 1
  grep -q "$PODIP" "$EVIDENCE" || exit 1
fi

exit 0
