#!/bin/bash

kubectl create deployment pi-web --image=nginx:stable-alpine --replicas=2

touch /tmp/step2-applied
