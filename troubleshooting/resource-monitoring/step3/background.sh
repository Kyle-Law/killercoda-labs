#!/bin/bash

kubectl run mem-hog --image=polinux/stress --command -- stress --vm 1 --vm-bytes 256M --vm-hang 3600
kubectl run mem-light --image=busybox --command -- sh -c "sleep 3600"

touch /tmp/step3-applied
