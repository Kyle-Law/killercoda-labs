#!/bin/bash

kubectl get pv static-pv -o jsonpath='{.status.phase}' | grep -q Available || exit 1
kubectl get pv static-pv -o jsonpath='{.spec.capacity.storage}' | grep -q 100Mi || exit 1
kubectl get pv static-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' | grep -q Retain
