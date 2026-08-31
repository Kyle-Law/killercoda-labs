#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete app podinfo -n argocd --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://stefanprodan.github.io/podinfo
    chart: podinfo
    targetRevision: 6.5.4
    helm:
      parameters:
      - name: replicaCount
        value: "1"
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

argocd app sync podinfo --core
argocd app set podinfo --core --helm-set replicaCount=2
argocd app sync podinfo --core
argocd app set podinfo --core --helm-set replicaCount=3
argocd app sync podinfo --core
kubectl -n default rollout status deployment/podinfo --timeout=90s

touch /tmp/step2-applied
