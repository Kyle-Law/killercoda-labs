#!/bin/bash

kubectl config set-context --current --namespace=argocd

kubectl delete app app-of-apps example.guestbook example.kustomize-guestbook -n argocd --ignore-not-found
kubectl delete ns guestbook kustomize-guestbook --ignore-not-found

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

touch /tmp/step2-applied
