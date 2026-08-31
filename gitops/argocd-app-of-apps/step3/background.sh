#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete app app-of-apps example.guestbook example.kustomize-guestbook -n argocd --ignore-not-found
kubectl delete ns guestbook kustomize-guestbook --ignore-not-found

touch /tmp/step3-applied
