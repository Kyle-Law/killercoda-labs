#!/bin/bash

ARGOCD_VERSION=v3.5.2

if ! command -v argocd >/dev/null 2>&1; then
  curl -sSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
  chmod +x /usr/local/bin/argocd
fi

echo "y" | argocd login localhost:30080 --username admin --password "$(cat /root/argocd-admin-password.txt)" --plaintext >/dev/null 2>&1
argocd app set solar-system --sync-policy none >/dev/null 2>&1
argocd app sync solar-system --timeout 120 >/dev/null 2>&1

for i in $(seq 1 30); do
  [ "$(kubectl -n solar-system get deployment solar-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" == "2" ] && break
  sleep 3
done

touch /tmp/step4-applied
