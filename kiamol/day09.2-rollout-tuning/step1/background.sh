#!/bin/bash

kubectl create deployment payments --image=nginx:1.25-alpine --replicas=2
kubectl rollout status deployment/payments --timeout=120s

touch /tmp/step1-applied
