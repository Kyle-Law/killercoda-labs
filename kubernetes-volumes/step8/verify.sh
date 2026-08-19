#!/bin/bash

if kubectl get pod dynamic-pod >/dev/null 2>&1; then exit 1; fi
if kubectl get pvc dynamic-pvc >/dev/null 2>&1; then exit 1; fi

# no leftover PV should reference the deleted claim
if kubectl get pv -o yaml | grep -q "name: dynamic-pvc"; then exit 1; fi

exit 0
