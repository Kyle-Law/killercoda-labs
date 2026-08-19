#!/bin/bash

kubectl create serviceaccount deployer-sa
kubectl create role deployer-role --verb=get,list,watch --resource=deployments
kubectl create rolebinding deployer-sa-binding --role=deployer-role --serviceaccount=default:deployer-sa

touch /tmp/step2-applied
