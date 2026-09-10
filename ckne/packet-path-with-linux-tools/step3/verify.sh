#!/bin/bash

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
PODIP=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$WEBPOD" ] && [ -n "$PODIP" ] && [ -n "$CLUSTERIP" ] || exit 1

# The capture must be on client's veth, not web's -- and show the ClusterIP,
# never the Pod IP, since that translation hasn't happened yet at that point.
CAP=/root/cap-service.txt
[ -f "$CAP" ] || exit 1
grep -qE "IP [0-9.]+\.[0-9]+ > ${CLUSTERIP}\.80: .*HTTP: GET" "$CAP" || exit 1
grep -q "$PODIP" "$CAP" && exit 1

# The saved rule must be the real DNAT rule for this Service, naming the
# current Pod IP -- not a copy-pasted example from a previous run.
RULE=/root/dnat-rule.txt
[ -f "$RULE" ] || exit 1
grep -q "DNAT" "$RULE" || exit 1
grep -q "default/web" "$RULE" || exit 1
grep -q "$PODIP" "$RULE" || exit 1

exit 0
