#!/bin/bash

kubectl config set-context --current --namespace=argocd

argocd app set guestbook --core --sync-policy automated --self-heal
argocd app sync guestbook --core
kubectl -n default rollout status deployment/guestbook-ui --timeout=90s

touch /tmp/step4-applied
