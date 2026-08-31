#!/bin/bash

ARGOCD_VERSION=v3.5.2

if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
  kubectl create namespace argocd
  kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
  kubectl -n argocd wait --for=condition=available --timeout=240s deployment --all
  kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=240s

  # Serve plain HTTP -- a self-signed cert behind a NodePort just adds a
  # browser warning with nothing protecting anything behind it anyway.
  kubectl -n argocd patch configmap argocd-cmd-params-cm -p '{"data":{"server.insecure":"true"}}'
  kubectl -n argocd rollout restart deployment/argocd-server
  kubectl -n argocd rollout status deployment/argocd-server --timeout=180s
fi

for i in $(seq 1 30); do
  kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > /root/argocd-admin-password.txt
echo >> /root/argocd-admin-password.txt

touch /tmp/step1-applied
