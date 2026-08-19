#!/bin/bash

cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.orig

awk '{
  print $0
  if ($0 ~ /- kube-apiserver[[:space:]]*$/) {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)
    print indent "- --totally-bogus-flag=true"
  }
}' /etc/kubernetes/manifests/kube-apiserver.yaml > /tmp/kube-apiserver.yaml.new
cp /tmp/kube-apiserver.yaml.new /etc/kubernetes/manifests/kube-apiserver.yaml

touch /tmp/step3-applied
