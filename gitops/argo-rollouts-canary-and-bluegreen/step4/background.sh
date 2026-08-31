#!/bin/bash

kubectl delete rollout rollouts-demo rollouts-bluegreen -n default --ignore-not-found
kubectl delete svc rollouts-bluegreen-active rollouts-bluegreen-preview -n default --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rollouts-bluegreen-active
  namespace: default
spec:
  selector:
    app: rollouts-bluegreen
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: rollouts-bluegreen-preview
  namespace: default
spec:
  selector:
    app: rollouts-bluegreen
  ports:
  - port: 80
    targetPort: 8080
EOF

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollouts-bluegreen
  namespace: default
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: rollouts-bluegreen-active
      previewService: rollouts-bluegreen-preview
      autoPromotionEnabled: false
  selector:
    matchLabels:
      app: rollouts-bluegreen
  template:
    metadata:
      labels:
        app: rollouts-bluegreen
    spec:
      containers:
      - name: rollouts-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - containerPort: 8080
EOF

for i in $(seq 1 30); do
  [ "$(kubectl -n default get rollout rollouts-bluegreen -o jsonpath='{.status.phase}' 2>/dev/null)" == "Healthy" ] && break
  sleep 3
done

touch /tmp/step4-applied
