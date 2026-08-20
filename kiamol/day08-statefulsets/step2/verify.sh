#!/bin/bash

POD_IP=$(kubectl get pod web-0 -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -n "$POD_IP" ] || exit 1

ANSWER=$(tr -d '[:space:]' < /root/web0-dns-ip.txt 2>/dev/null)
[ "$ANSWER" == "$POD_IP" ]
