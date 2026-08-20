#!/bin/bash

kubectl exec scoped-pod -- cat /mounted/marker.txt 2>/dev/null | grep -q "secret-a" || exit 1

if kubectl exec scoped-pod -- test -e /mounted/app-b 2>/dev/null; then exit 1; fi
if kubectl exec scoped-pod -- test -e /mounted/../app-b 2>/dev/null; then exit 1; fi

exit 0
