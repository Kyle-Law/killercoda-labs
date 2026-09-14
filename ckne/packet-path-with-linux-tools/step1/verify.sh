#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · Find the veth"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

FILE=/root/veth-web.txt
[ -f "$FILE" ] || fail \
  "No answer file at $FILE." \
  "" \
  "Write the name of the host-side interface belonging to the web Pod:" \
  "  echo '<ifname>' > $FILE"

ANSWER=$(tr -d '[:space:]' < "$FILE")
[ -n "$ANSWER" ] || fail \
  "$FILE is empty." \
  "" \
  "It should hold one interface name and nothing else, as it appears in" \
  "'ip link' on the node."

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || fail \
  "No running Pod with label app=web, so there is no veth to find." \
  "" \
  "  kubectl get pods -l app=web -o wide"

# Computed independently of whatever /usr/local/bin/podveth does, so a bug in
# that helper couldn't make this pass for the wrong reason.
IFLINK=$(kubectl exec "$WEBPOD" -- cat /sys/class/net/eth0/iflink 2>/dev/null)
[ -n "$IFLINK" ] || fail \
  "Could not read /sys/class/net/eth0/iflink inside $WEBPOD." \
  "" \
  "  kubectl exec $WEBPOD -- cat /sys/class/net/eth0/iflink"

HAVE=$(cat "/sys/class/net/${ANSWER}/ifindex" 2>/dev/null)
[ "$HAVE" == "$IFLINK" ] && pass

if [ -z "$HAVE" ]; then
  fail \
    "There is no interface named '$ANSWER' on this node." \
    "" \
    "  ip -o link | head -20" ;
fi

fail \
  "'$ANSWER' is an interface on the node, but not this Pod's." \
  "" \
  "  ifindex of $ANSWER:        $HAVE" \
  "  iflink inside $WEBPOD:  $IFLINK" \
  "" \
  "A veth is a pair, and the number inside the Pod is the index of the other" \
  "end. Match on that rather than on the name -- names are a CNI's choice and" \
  "differ between them, while the index is the kernel's:" \
  "  kubectl exec $WEBPOD -- cat /sys/class/net/eth0/iflink" \
  "  for f in /sys/class/net/*/ifindex; do echo \"\$(cat \$f) \$f\"; done | grep \"^\$IFLINK \""
