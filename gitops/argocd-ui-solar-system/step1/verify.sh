#!/bin/bash

TYPE=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$TYPE" == "NodePort" ] || exit 1

NODEPORT=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
[ "$NODEPORT" == "30080" ] || exit 1

for i in $(seq 1 24); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:30080/" 2>/dev/null)
  [ "$CODE" == "200" ] && exit 0
  sleep 5
done

exit 1
