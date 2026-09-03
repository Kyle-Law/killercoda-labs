#!/bin/bash

# Record whether this cluster actually serves the GA DRA API, so step 1 can
# tell the learner plainly rather than failing with a confusing error.
kubectl api-resources --api-group=resource.k8s.io 2>/dev/null > /root/dra-api.txt
kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -2 > /root/k8s-version.txt

for img in registry.k8s.io/dra-example-driver/dra-example-driver:v0.4.0 busybox:1.36; do
  ctr -n k8s.io images pull "$img" >/dev/null 2>&1 || crictl pull "$img" >/dev/null 2>&1 || true
done

touch /tmp/.initfinished
