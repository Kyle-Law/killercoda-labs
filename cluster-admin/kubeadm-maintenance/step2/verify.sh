#!/bin/bash

BEFORE=$(cat /root/apiserver-cert-before.txt 2>/dev/null)
AFTER=$(kubeadm certs check-expiration | grep '^apiserver ')

[ -n "$BEFORE" ] && [ -n "$AFTER" ] || exit 1
[ "$AFTER" != "$BEFORE" ]
