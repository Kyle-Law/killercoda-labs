#!/bin/bash

# don't assume etcdctl is preinstalled - install it matching the running
# etcd container's version if it's missing
if ! command -v etcdctl >/dev/null 2>&1; then
  RAW_TAG=$(kubectl get pod -n kube-system -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}' | sed 's/.*://')
  ETCD_VER="v${RAW_TAG%%-*}"
  curl -sL "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz" -o /tmp/etcd.tar.gz
  tar xzf /tmp/etcd.tar.gz -C /tmp
  cp "/tmp/etcd-${ETCD_VER}-linux-amd64/etcdctl" /usr/local/bin/etcdctl
fi

kubectl create configmap important-data --from-literal=value=must-survive-a-restore

touch /tmp/step1-applied
