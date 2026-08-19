#!/bin/bash

kubectl create namespace quota-ns
kubectl create quota compute-quota -n quota-ns --hard=requests.cpu=200m,requests.memory=256Mi
kubectl create deployment web -n quota-ns --image=nginx:stable-alpine --replicas=3
# each replica alone requests more than the entire namespace is allowed -
# no replica can ever be admitted
kubectl set resources deployment web -n quota-ns --requests=cpu=250m,memory=64Mi

touch /tmp/step2-applied
