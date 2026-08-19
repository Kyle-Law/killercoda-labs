#!/bin/bash

cp /etc/kubernetes/manifests/kube-controller-manager.yaml /root/kube-controller-manager.yaml.orig

awk '{
  print $0
  if ($0 ~ /- kube-controller-manager[[:space:]]*$/) {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)
    print indent "- --totally-bogus-flag=true"
  }
}' /etc/kubernetes/manifests/kube-controller-manager.yaml > /tmp/kube-controller-manager.yaml.new
cp /tmp/kube-controller-manager.yaml.new /etc/kubernetes/manifests/kube-controller-manager.yaml

# wait for it to actually go unready before creating the Deployment, so the
# "no ReplicaSet appears" symptom is guaranteed rather than a timing race
for i in $(seq 1 30); do
  READY=$(kubectl get pods -n kube-system -l component=kube-controller-manager -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "false" ] && break
  sleep 2
done

kubectl create deployment web --image=nginx:stable-alpine --replicas=2

touch /tmp/step2-applied
