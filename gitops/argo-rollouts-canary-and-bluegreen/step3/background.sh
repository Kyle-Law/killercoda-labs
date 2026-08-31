#!/bin/bash

kubectl delete rollout rollouts-demo -n default --ignore-not-found

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

touch /tmp/step3-applied
