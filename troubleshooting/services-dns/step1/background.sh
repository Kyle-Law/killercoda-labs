#!/bin/bash

kubectl create deployment backend --image=nginx:stable-alpine --replicas=2
kubectl expose deployment backend --port=80 --target-port=80 --name=backend-svc

# corrupt the selector so it no longer matches the Deployment's Pods
kubectl patch service backend-svc -p '{"spec":{"selector":{"app":"backend-typo"}}}'

touch /tmp/step1-applied
