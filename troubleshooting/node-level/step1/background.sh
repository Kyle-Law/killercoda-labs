#!/bin/bash

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl cordon "$NODE"

kubectl create deployment stuck-app --image=nginx:stable-alpine --replicas=2

touch /tmp/step1-applied
