#!/bin/bash

kubectl delete application solar-system -n argocd --ignore-not-found
kubectl delete namespace solar-system --ignore-not-found

touch /tmp/step3-applied
