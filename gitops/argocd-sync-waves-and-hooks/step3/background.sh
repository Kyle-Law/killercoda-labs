#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete app pre-post-sync -n argocd --ignore-not-found
kubectl -n default delete deployment,svc pre-post-sync-kustomize-guestbook-ui --ignore-not-found
kubectl -n default delete job pre-post-sync-before pre-post-sync-after --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pre-post-sync
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: pre-post-sync
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

touch /tmp/step3-applied
