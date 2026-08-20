#!/bin/bash

kubectl get pvc data-data-app-0 >/dev/null 2>&1 || exit 1
kubectl get pvc data-data-app-1 >/dev/null 2>&1 || exit 1

kubectl exec data-app-0 -- cat /data/marker.txt 2>/dev/null | grep -q "zero" || exit 1
if kubectl exec data-app-1 -- cat /data/marker.txt >/dev/null 2>&1; then exit 1; fi

exit 0
