#!/bin/bash

kubectl create serviceaccount viewer-sa
kubectl create role pod-reader --verb=get,list,watch --resource=pods
# deliberately no RoleBinding

touch /tmp/step1-applied
