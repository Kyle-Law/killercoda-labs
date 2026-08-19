#!/bin/bash

mv /etc/kubernetes/kubelet.conf /root/kubelet.conf.orig
systemctl restart kubelet

touch /tmp/step3-applied
