#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete applicationset guestbook-envs -n argocd --ignore-not-found
kubectl delete app guestbook-dev guestbook-staging guestbook-prod -n argocd --ignore-not-found
kubectl delete ns guestbook-dev guestbook-staging guestbook-prod --ignore-not-found

touch /tmp/step4-applied
