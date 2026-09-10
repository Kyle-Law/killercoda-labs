#!/bin/bash

FILE=/root/cap-direct.txt
[ -f "$FILE" ] || exit 1

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
PODIP=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
[ -n "$WEBPOD" ] && [ -n "$PODIP" ] || exit 1

# Confirms the capture happened on the right interface (the one the file
# names as its subject) and actually shows the direct, Service-free request:
# a GET arriving addressed to the Pod's own IP.
grep -q "listening on $(cat /root/veth-web.txt 2>/dev/null)," "$FILE" || exit 1
grep -qE "IP [0-9.]+\.[0-9]+ > ${PODIP}\.8080: .*HTTP: GET" "$FILE" || exit 1

exit 0
