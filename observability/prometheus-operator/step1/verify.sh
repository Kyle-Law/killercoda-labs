#!/bin/bash

READY=$(kubectl get deployment prometheus-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$READY" == "1" ] || exit 1

ACTUAL=$(kubectl get crd -o name 2>/dev/null | grep -c "monitoring.coreos.com")
[ "$ACTUAL" -ge 1 ] 2>/dev/null || exit 1

ANSWER=$(tr -d '[:space:]' < /root/crd-count.txt 2>/dev/null)
[ "$ANSWER" == "$ACTUAL" ]
