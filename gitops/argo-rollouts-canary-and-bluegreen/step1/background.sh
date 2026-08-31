#!/bin/bash

ROLLOUTS_VERSION=v1.10.0

if ! command -v kubectl-argo-rollouts >/dev/null 2>&1; then
  curl -sSL -o /usr/local/bin/kubectl-argo-rollouts \
    "https://github.com/argoproj/argo-rollouts/releases/download/${ROLLOUTS_VERSION}/kubectl-argo-rollouts-linux-amd64"
  chmod +x /usr/local/bin/kubectl-argo-rollouts
fi

if ! kubectl get deployment argo-rollouts -n argo-rollouts >/dev/null 2>&1; then
  kubectl create namespace argo-rollouts
  # The Rollout and AnalysisRun CRDs exceed kubectl apply's 262144-byte
  # last-applied-configuration annotation limit -- server-side apply
  # doesn't use that annotation, so it's required here, not optional.
  kubectl apply -n argo-rollouts --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-rollouts/${ROLLOUTS_VERSION}/manifests/install.yaml"
  kubectl -n argo-rollouts wait --for=condition=available --timeout=180s deployment --all
fi

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollouts-demo
  namespace: default
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 60
      - pause: {duration: 10}
  selector:
    matchLabels:
      app: rollouts-demo
  template:
    metadata:
      labels:
        app: rollouts-demo
    spec:
      containers:
      - name: rollouts-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - containerPort: 8080
EOF

for i in $(seq 1 30); do
  [ "$(kubectl -n default get rollout rollouts-demo -o jsonpath='{.status.phase}' 2>/dev/null)" == "Healthy" ] && break
  sleep 3
done

touch /tmp/step1-applied
