#!/bin/bash

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

touch /tmp/step2-applied
