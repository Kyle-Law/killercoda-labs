#!/bin/bash

kubectl create deployment stateful-cache --image=busybox --replicas=2 -- sh -c "sleep 3600"
kubectl create deployment always-on --image=nginx:1.25-alpine --replicas=4

touch /tmp/step2-applied
