#!/bin/bash

INIT_REASON=$(kubectl get pod configured-app -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}' 2>/dev/null)
[ "$INIT_REASON" == "Completed" ] || exit 1

READY=$(kubectl get pod configured-app -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
[ "$READY" == "true" ] || exit 1

kubectl exec configured-app -c app -- cat /config/status.txt 2>/dev/null | grep -q "ready"
