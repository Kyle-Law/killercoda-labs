#!/bin/bash

# A real CNI, installed and running.
for _ in $(seq 1 24); do
  DESIRED=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  READY=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [ -n "$DESIRED" ] && [ "$DESIRED" != "0" ] && [ "$DESIRED" == "$READY" ] && break
  sleep 5
done
[ -n "$DESIRED" ] && [ "$DESIRED" == "$READY" ] || exit 1

# The demonstration is only finished once the policy has been taken off again.
kubectl get netpol deny-all-to-web >/dev/null 2>&1 && exit 1

# web must be running and managed by Cilium -- an endpoint exists only for a
# Pod that Cilium itself set up, which is what the recreation step was for.
for _ in $(seq 1 24); do
  IP=$(kubectl get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
  if [ -n "$IP" ]; then
    kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
      cilium-dbg endpoint list 2>/dev/null | grep -q "$IP" && exit 0
  fi
  sleep 5
done

exit 1
