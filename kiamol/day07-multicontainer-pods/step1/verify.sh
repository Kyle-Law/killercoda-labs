#!/bin/bash

kubectl exec multi-pod -c writer -- sh -c "echo verify-write > /data-rw/verify.txt" || exit 1
sleep 1

kubectl exec multi-pod -c reader -- cat /data-ro/verify.txt 2>/dev/null | grep -q "verify-write" || exit 1

if kubectl exec multi-pod -c reader -- sh -c "echo bad >> /data-ro/verify.txt" 2>/dev/null; then exit 1; fi

exit 0
