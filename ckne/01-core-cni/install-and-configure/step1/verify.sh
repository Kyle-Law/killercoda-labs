#!/bin/bash

# The task was explicitly to do this without installing CNI software, so a
# DaemonSet mounting the config directory means the point was skipped rather
# than made.
CNI_DS=$(kubectl get ds -A -o jsonpath='{range .items[*]}{.metadata.name}{range .spec.template.spec.volumes[*]}{" "}{.hostPath.path}{end}{"\n"}{end}' 2>/dev/null \
  | awk '/\/etc\/cni/ {print $1}')
[ -n "$CNI_DS" ] && exit 1

# A network configuration has to actually be on disk for the kubelet to read.
[ -z "$(ls -A /etc/cni/net.d 2>/dev/null)" ] && exit 1

for _ in $(seq 1 24); do
  READY=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

  # Ready on its own is not enough -- the claim is that Pods now get addresses,
  # so require a real workload running with one.
  IP=$(kubectl get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)

  if [ "$READY" == "True" ] && [ -n "$IP" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
