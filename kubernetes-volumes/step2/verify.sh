#!/bin/bash

kubectl get pod hostpath-pod -o yaml | grep -q "hostPath:" || exit 1

kubectl exec hostpath-pod -- cat /usr/share/nginx/html/index.html | grep -q served-from-host
