#!/bin/bash

kubectl -n kube-system scale deployment coredns --replicas=0

touch /tmp/step3-applied
