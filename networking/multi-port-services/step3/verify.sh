#!/bin/bash

TYPE=$(kubectl get svc external-api -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$TYPE" == "ExternalName" ] || exit 1

EXTNAME=$(kubectl get svc external-api -o jsonpath='{.spec.externalName}' 2>/dev/null)
[ "$EXTNAME" == "example.com" ] || exit 1

for i in $(seq 1 4); do
  kubectl exec dns-client -- nslookup external-api 2>/dev/null | grep -q "example.com" && exit 0
  sleep 3
done

exit 1
