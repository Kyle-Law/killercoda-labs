#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete app podinfo-helm -n argocd --ignore-not-found
kubectl -n default delete deployment,svc podinfo-helm --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo-helm
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://stefanprodan.github.io/podinfo
    chart: podinfo
    targetRevision: 6.5.4
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

argocd app sync podinfo-helm --core

touch /tmp/step3-applied
