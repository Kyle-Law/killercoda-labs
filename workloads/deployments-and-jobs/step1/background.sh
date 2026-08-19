#!/bin/bash

kubectl create deployment frontend --image=nginx:1.25-alpine --replicas=3

touch /tmp/step1-applied
