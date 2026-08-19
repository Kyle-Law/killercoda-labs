#!/bin/bash

kubectl create serviceaccount node-viewer-sa
kubectl create clusterrole node-viewer --verb=get,list,watch --resource=nodes
# a namespaced RoleBinding referencing a ClusterRole - a common real mistake,
# and it will never authorize a cluster-scoped resource like nodes
kubectl create rolebinding node-viewer-binding --clusterrole=node-viewer --serviceaccount=default:node-viewer-sa

touch /tmp/step3-applied
