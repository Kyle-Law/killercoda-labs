#!/bin/bash

# the cluster must actually serve the GA DRA API
kubectl api-resources --api-group=resource.k8s.io 2>/dev/null | grep -q resourceslices || exit 1

# driver installed and its kubelet plugin running
for i in $(seq 1 36); do
  READY=$(kubectl get pods -n dra-example-driver --no-headers 2>/dev/null | grep -c "Running")
  [ "$READY" -ge 1 ] 2>/dev/null && break
  sleep 5
done
[ "$READY" -ge 1 ] 2>/dev/null || exit 1

# and it must have published an inventory - that is the point of the step
kubectl get deviceclass gpu.example.com >/dev/null 2>&1 || exit 1
for i in $(seq 1 24); do
  N=$(kubectl get resourceslice -o jsonpath='{range .items[*]}{.spec.devices[*].name}{"\n"}{end}' 2>/dev/null | tr ' ' '\n' | grep -c "gpu-")
  [ "$N" -ge 1 ] 2>/dev/null && exit 0
  sleep 5
done

exit 1
