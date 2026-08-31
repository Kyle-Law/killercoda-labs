#!/bin/bash

ARGOCD_VERSION=v3.5.2

if ! command -v argocd >/dev/null 2>&1; then
  curl -sSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
  chmod +x /usr/local/bin/argocd
fi

if ! kubectl get deployment argocd-repo-server -n argocd >/dev/null 2>&1; then
  kubectl create namespace argocd
  kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/core-install.yaml"
  kubectl -n argocd wait --for=condition=available --timeout=180s deployment --all
  kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=180s
fi

kubectl config set-context --current --namespace=argocd

# core-install.yaml never bootstraps a "default" AppProject on its own.
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: default
  namespace: argocd
spec:
  description: Default project
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

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

touch /tmp/step1-applied
