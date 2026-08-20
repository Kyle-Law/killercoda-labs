#!/bin/bash

# must no longer expose the whole node root
if kubectl get pod risky-pod -o yaml | grep -q "path: /$"; then exit 1; fi

kubectl exec risky-pod -- cat /mounted/marker.txt 2>/dev/null | grep -q "secret-a" || exit 1
if kubectl exec risky-pod -- test -e /mounted/app-b 2>/dev/null; then exit 1; fi

exit 0
