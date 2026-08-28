#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

touch /tmp/.initfinished
