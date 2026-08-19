#!/bin/bash

kubectl get pod pv-pod -o yaml | grep -q "claimName: static-pvc" || exit 1

kubectl exec pv-pod -- cat /usr/share/nginx/html/index.html | grep -q data-survives
