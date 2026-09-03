#!/bin/bash

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "$NODE" > /root/nodename

# Advertise 4 GPUs as an extended resource. There is no GPU here - extended
# resources are opaque to Kubernetes and need no device plugin or hardware,
# so the scheduler treats these exactly as it would real accelerators.
kubectl patch node "$NODE" --subresource=status --type=json \
  -p '[{"op":"add","path":"/status/capacity/nvidia.com~1gpu","value":"4"}]' >/dev/null 2>&1

# pre-pull what the later steps need
for img in registry.k8s.io/kueue/kueue:v0.10.1 \
           registry.k8s.io/kubebuilder/kube-rbac-proxy:v0.16.0 \
           busybox:1.36; do
  ctr -n k8s.io images pull "$img" >/dev/null 2>&1 || crictl pull "$img" >/dev/null 2>&1 || true
done

touch /tmp/.initfinished
