#!/bin/bash

kubectl get pvc dynamic-pvc -o jsonpath='{.status.phase}' | grep -q Bound || exit 1

PV=$(kubectl get pvc dynamic-pvc -o jsonpath='{.spec.volumeName}')
[ -n "$PV" ] || exit 1

kubectl get pv "$PV" >/dev/null 2>&1
