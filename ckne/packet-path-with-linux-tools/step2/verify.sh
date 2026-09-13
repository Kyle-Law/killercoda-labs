#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · Watch a packet leave"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

FILE=/root/cap-direct.txt
[ -f "$FILE" ] || fail \
  "No capture at $FILE." \
  "" \
  "Capture on the veth you found in step 1 while making one request straight to" \
  "the Pod's address, and save it there:" \
  "  tcpdump -i \$(cat /root/veth-web.txt) -n -c 10 -A tcp > $FILE 2>&1 &"

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
PODIP=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
[ -n "$WEBPOD" ] && [ -n "$PODIP" ] || fail \
  "No running Pod with label app=web, so there is nothing to have captured." \
  "" \
  "  kubectl get pods -l app=web -o wide"

# Confirms the capture happened on the right interface (the one the file
# names as its subject) and actually shows the direct, Service-free request:
# a GET arriving addressed to the Pod's own IP.
VETH=$(cat /root/veth-web.txt 2>/dev/null)
grep -q "listening on ${VETH}," "$FILE" || fail \
  "$FILE is not a capture taken on '${VETH:-<no interface recorded>}'." \
  "" \
  "Its first line says which interface tcpdump was listening on:" \
  "  head -1 $FILE" \
  "" \
  "It has to be the Pod's own veth. A capture on the node's uplink, or on any," \
  "would show the same traffic mixed in with everything else and could not tell" \
  "you what this Pod in particular sent."

grep -qE "IP [0-9.]+\.[0-9]+ > ${PODIP}\.8080: .*HTTP: GET" "$FILE" || fail \
  "The capture does not contain a GET addressed to ${PODIP}:8080." \
  "" \
  "What it does contain:" \
  "$(grep -E '^[0-9]{2}:' "$FILE" | head -4 | sed 's/^/  /')" \
  "" \
  "The request has to go straight to the Pod's address, not through a Service --" \
  "the Service path is step 3, and it looks different. Ask tcpdump for the" \
  "payload (-A) so the GET line is there to match, and start it before the" \
  "request:" \
  "  tcpdump -i $VETH -n -c 10 -A tcp > $FILE 2>&1 &" \
  "  sleep 1" \
  "  kubectl exec client -- wget -qO- -T5 http://${PODIP}:8080/hostname"

pass
