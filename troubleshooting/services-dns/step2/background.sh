#!/bin/bash

kubectl create deployment web2 --image=nginx:stable-alpine --replicas=1
# targetPort is wrong: nginx listens on 80, not 8080
kubectl expose deployment web2 --port=80 --target-port=8080 --name=web2-svc

kubectl run test-client --image=busybox:1.28 --command -- sleep 3600

touch /tmp/step2-applied
