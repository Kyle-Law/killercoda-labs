#!/bin/bash

FILE=/root/veth-web.txt
[ -f "$FILE" ] || exit 1
ANSWER=$(tr -d '[:space:]' < "$FILE")
[ -n "$ANSWER" ] || exit 1

WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WEBPOD" ] || exit 1

# Computed independently of whatever /usr/local/bin/podveth does, so a bug in
# that helper couldn't make this pass for the wrong reason.
IFLINK=$(kubectl exec "$WEBPOD" -- cat /sys/class/net/eth0/iflink 2>/dev/null)
[ -n "$IFLINK" ] || exit 1

[ "$(cat "/sys/class/net/${ANSWER}/ifindex" 2>/dev/null)" == "$IFLINK" ] && exit 0
exit 1
