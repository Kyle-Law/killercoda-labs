#!/bin/bash

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml

kubectl create deployment web --image=nginx:stable-alpine --replicas=2
kubectl expose deployment web --port=80

# used by verify.sh and available for manual testing too
kubectl run curl-test --image=busybox:1.28 --command -- sleep 3600

touch /tmp/step1-applied
