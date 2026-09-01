#!/bin/bash

ARGOCD_TYPE=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$ARGOCD_TYPE" == "NodePort" ] || exit 1
ARGOCD_PORT=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
[ "$ARGOCD_PORT" == "30080" ] || exit 1

GITEA_TYPE=$(kubectl -n gitea get svc gitea -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$GITEA_TYPE" == "NodePort" ] || exit 1
GITEA_PORT=$(kubectl -n gitea get svc gitea -o jsonpath='{.spec.ports[?(@.port==3000)].nodePort}' 2>/dev/null)
[ "$GITEA_PORT" == "30300" ] || exit 1

for i in $(seq 1 24); do
  ARGOCD_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:30080/" 2>/dev/null)
  GITEA_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:30300/" 2>/dev/null)
  [ "$ARGOCD_CODE" == "200" ] && [ "$GITEA_CODE" == "200" ] && exit 0
  sleep 5
done

exit 1
