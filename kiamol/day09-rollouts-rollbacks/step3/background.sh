#!/bin/bash

kubectl create deployment api --image=nginx:1.25-alpine --replicas=2

touch /tmp/step3-applied
