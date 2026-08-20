#!/bin/bash

ORIGINAL=$(tr -d '[:space:]' < /root/original-web0-uid.txt 2>/dev/null)
[ -n "$ORIGINAL" ] || exit 1

CURRENT=$(kubectl get pod web-0 -o jsonpath='{.metadata.uid}' 2>/dev/null)
[ -n "$CURRENT" ] || exit 1
[ "$CURRENT" != "$ORIGINAL" ] || exit 1

kubectl get pod web-1 >/dev/null 2>&1
