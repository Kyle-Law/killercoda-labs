#!/bin/bash

# The plugin binary named by the conflist has to be back where the kubelet
# looks for it -- leaving the node in the broken state is the one way to
# finish this step wrong.
[ -x /opt/cni/bin/cilium-cni ] || exit 1

# Cilium's own config must be the one in force, not a leftover from step 1.
[ -f /etc/cni/net.d/05-cilium.conflist ] || exit 1
ls /etc/cni/net.d/*.conflist 2>/dev/null | grep -qv '05-cilium.conflist' && exit 1

# And the proof that the restored binary works: a Pod that can be created now.
kubectl delete pod cniprobe --ignore-not-found --wait=true >/dev/null 2>&1
kubectl run cniprobe --image=registry.k8s.io/e2e-test-images/agnhost:2.53 \
  --command -- /bin/sh -c "sleep 300" >/dev/null 2>&1

for _ in $(seq 1 24); do
  IP=$(kubectl get pod cniprobe -o jsonpath='{.status.podIP}' 2>/dev/null)
  PHASE=$(kubectl get pod cniprobe -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$PHASE" == "Running" ] && [ -n "$IP" ]; then
    kubectl delete pod cniprobe --wait=false >/dev/null 2>&1
    exit 0
  fi
  sleep 5
done

kubectl delete pod cniprobe --wait=false >/dev/null 2>&1
exit 1
