#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

helm install webserver podinfo/podinfo \
  --set ui.message="Hello from Helm" \
  --set replicaCount=2

touch /tmp/.initfinished
