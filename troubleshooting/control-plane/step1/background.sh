#!/bin/bash

cp /etc/kubernetes/manifests/kube-scheduler.yaml /root/kube-scheduler.yaml.orig

awk '{
  print $0
  if ($0 ~ /- kube-scheduler[[:space:]]*$/) {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)
    print indent "- --totally-bogus-flag=true"
  }
}' /etc/kubernetes/manifests/kube-scheduler.yaml > /tmp/kube-scheduler.yaml.new
cp /tmp/kube-scheduler.yaml.new /etc/kubernetes/manifests/kube-scheduler.yaml

touch /tmp/step1-applied
