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

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: apps
    helm:
      valuesObject:
        config:
          spec:
            destination:
              server: https://kubernetes.default.svc
            source:
              repoURL: https://github.com/argoproj/argocd-example-apps
              targetRevision: HEAD
        applications:
        - name: guestbook
          destination: {}
        - name: kustomize-guestbook
          destination: {}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
EOF

argocd app sync app-of-apps --core

touch /tmp/step1-applied
