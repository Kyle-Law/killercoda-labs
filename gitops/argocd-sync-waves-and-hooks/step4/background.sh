#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete app sync-waves -n argocd --ignore-not-found
kubectl -n default delete replicaset,svc backend frontend --ignore-not-found
kubectl -n default delete job maint-page-up maint-page-down --ignore-not-found
kubectl -n default get job -o name 2>/dev/null | grep upgrade-sql-schema | xargs -r kubectl -n default delete

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sync-waves
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: sync-waves
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

argocd app sync sync-waves --core

touch /tmp/step4-applied
