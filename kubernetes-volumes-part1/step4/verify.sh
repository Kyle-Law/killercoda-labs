#!/bin/bash

kubectl get pvc static-pvc -o jsonpath='{.status.phase}' | grep -q Bound || exit 1
kubectl get pvc static-pvc -o jsonpath='{.spec.volumeName}' | grep -q static-pv
