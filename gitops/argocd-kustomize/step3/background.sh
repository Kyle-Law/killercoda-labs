#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete app kustomize-guestbook -n argocd --ignore-not-found
kubectl -n default delete deployment,svc kustomize-guestbook-ui test-guestbook-ui --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: kustomize-guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

argocd app sync kustomize-guestbook --core

touch /tmp/step3-applied
