#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

kubectl create ns team-blue
kubectl create ns team-yellow
helm -n team-blue install webserver podinfo/podinfo
helm -n team-yellow install apiserver podinfo/podinfo

touch /tmp/.initfinished
