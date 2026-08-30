#!/bin/bash

kubectl config set-context --current --namespace=argocd

argocd app set guestbook --core --sync-policy manual
argocd app sync guestbook --core
kubectl -n default rollout status deployment/guestbook-ui --timeout=90s

touch /tmp/step3-applied
