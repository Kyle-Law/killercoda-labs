#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo >/dev/null 2>&1
helm repo update >/dev/null 2>&1

helm install podinfo3 podinfo/podinfo --version 6.5.4 --set replicaCount=2 --wait --timeout 90s

touch /tmp/step3-applied
