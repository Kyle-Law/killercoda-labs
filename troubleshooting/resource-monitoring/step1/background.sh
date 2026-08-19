#!/bin/bash

kubectl run low-cpu --image=busybox --command -- sh -c "sleep 3600"
kubectl run high-cpu --image=polinux/stress --command -- stress --cpu 2 --timeout 3600

touch /tmp/step1-applied
