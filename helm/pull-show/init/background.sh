#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

touch /tmp/.initfinished
