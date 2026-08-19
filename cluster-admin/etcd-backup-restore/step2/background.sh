#!/bin/bash

kubectl delete configmap important-data
kubectl create configmap post-snapshot-junk --from-literal=oops=should-not-survive-restore

touch /tmp/step2-applied
