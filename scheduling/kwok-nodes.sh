#!/bin/bash
#
# kwok-nodes.sh -- fake nodes for the scheduler labs.
#
#   kwok-nodes.sh [COUNT]        default 12; ends with exactly COUNT fake nodes
#
# KWOK makes Node objects look Ready, and reports any Pod bound to them as
# Running, with no kubelet behind either. The real kube-scheduler places Pods on
# them; nothing on the scheduler's side is faked.
#
# Each lab that needs this copies the file into its own init/ and calls it.
# Resizing wipes and recreates the fake nodes, so nothing a lab did to one of
# them (a label, a taint) survives a resize.
#
# Pods that should land on fake nodes need both of these:
#
#   nodeSelector: {type: kwok}
#   tolerations:  [{key: kwok.x-k8s.io/node, operator: Exists}]
#
# The selector matters as much as the toleration. The real node has images in
# status.images and the fake ones have none, so ImageLocality favours the real
# node for any Pod that is free to go there, and it distorts every comparison.
#
# What keeps system Pods off the fake nodes:
#   - CoreDNS and other ordinary Pods: the NoSchedule taint below.
#   - Cilium's DaemonSets tolerate every taint, so the taint does nothing to
#     them. They carry nodeSelector kubernetes.io/os=linux, so the fake nodes
#     are labelled with a different OS and the DaemonSets never match them.
#     That needs no patching and no restart of the real agent. A DaemonSet
#     with no such selector would still put a (harmless) fake Pod on each node.

KWOK_VERSION=v0.8.0
COUNT=${1:-12}
ZONES=(zone-a zone-b zone-c)

export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

if ! kubectl -n kube-system get deploy kwok-controller >/dev/null 2>&1; then
  REL=https://github.com/kubernetes-sigs/kwok/releases/download/${KWOK_VERSION}
  kubectl apply -f "$REL/kwok.yaml" >/dev/null
  # node-initialize and node-heartbeat make nodes Ready; pod-ready and pod-delete
  # do the same for Pods bound to them.
  kubectl apply -f "$REL/stage-fast.yaml" >/dev/null
  kubectl -n kube-system rollout status deploy/kwok-controller --timeout=180s >/dev/null
fi

HAVE=$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l)
if [ "$HAVE" != "$COUNT" ]; then
  # By label, not by name: deleting 280 nodes by label took 2.8s, and deleting
  # them one name at a time ran at about a node a second.
  if [ "$HAVE" -gt 0 ]; then
    kubectl delete nodes -l type=kwok --wait=false >/dev/null 2>&1
    while [ "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l)" -gt 0 ]; do sleep 0.3; done
  fi

  for i in $(seq 0 $((COUNT - 1))); do
    Z=${ZONES[$((i % 3))]}
    cat <<YAML
---
apiVersion: v1
kind: Node
metadata:
  name: kwok-node-$i
  annotations:
    node.alpha.kubernetes.io/ttl: "0"
    kwok.x-k8s.io/node: fake
  labels:
    kubernetes.io/hostname: kwok-node-$i
    kubernetes.io/os: fake
    kubernetes.io/arch: amd64
    topology.kubernetes.io/zone: $Z
    type: kwok
spec:
  taints:
  - key: kwok.x-k8s.io/node
    value: fake
    effect: NoSchedule
status:
  allocatable: {cpu: "8", memory: 32Gi, pods: "110"}
  capacity: {cpu: "8", memory: 32Gi, pods: "110"}
  nodeInfo: {architecture: amd64, operatingSystem: linux, kubeletVersion: fake, kubeProxyVersion: fake, osImage: fake, kernelVersion: fake, containerRuntimeVersion: fake, machineID: fake, systemUUID: fake, bootID: fake}
YAML
  done | kubectl apply -f - >/dev/null
fi

# Ready is reported by KWOK a moment after the object exists, and a label read
# straight after creation was seen to come back empty once.
for _ in $(seq 1 120); do
  READY=$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)
  [ "$READY" -ge "$COUNT" ] && break
  sleep 0.5
done

# Ready is not schedulable. A new node carries node.kubernetes.io/not-ready:NoSchedule
# until the node lifecycle controller removes it, and it removes them one node at a
# time at about five a second: 12 nodes clear in a few seconds, 250 in about a
# minute, 500 in about two. Until then those nodes are not candidates for anything,
# which silently shrinks every "how many nodes did the scheduler look at" count.
for _ in $(seq 1 $((COUNT / 3 + 60))); do
  TAINTED=$(kubectl get nodes -l type=kwok -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' 2>/dev/null | grep -c 'node.kubernetes.io/not-ready')
  [ "$TAINTED" -eq 0 ] && break
  sleep 1
done
sleep 2

echo "kwok-nodes: $READY of $COUNT fake nodes Ready, ${TAINTED:-0} still tainted not-ready"
[ "$READY" -ge "$COUNT" ] && [ "${TAINTED:-0}" -eq 0 ]
