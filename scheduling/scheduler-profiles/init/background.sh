#!/bin/bash

mkdir -p /root/answers

# Killercoda shows only pass/fail, never a verify script's output, so each
# check writes its reason to /root/.check and `why` prints it.
cat > /usr/local/bin/why <<'WRAP'
#!/bin/bash
if [ -s /root/.check ]; then
  cat /root/.check
else
  echo "No check has run yet -- press CHECK, then run 'why' again."
fi
WRAP
chmod +x /usr/local/bin/why

# The cluster can still be coming up when this runs.
for _ in $(seq 1 60); do
  kubectl get nodes >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null 2>&1

# The static Pod manifest as kubeadm wrote it, in case a step goes wrong enough
# that the scheduler will not come back. A broken scheduler leaves every new Pod
# Pending with no events, including the Pods a check creates to test your work.
cp /etc/kubernetes/manifests/kube-scheduler.yaml /root/kube-scheduler.yaml.orig

# Fake nodes, for steps 2 and 3. This is scheduling/kwok-nodes.sh, verbatim.
cat > /root/kwok-nodes.sh <<'KWOKEOF'
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
sleep 2

echo "kwok-nodes: $READY of $COUNT fake nodes Ready"
[ "$READY" -ge "$COUNT" ]
KWOKEOF
chmod +x /root/kwok-nodes.sh
bash /root/kwok-nodes.sh 12 >/dev/null 2>&1
if [ "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)" -lt 12 ]; then
  touch /tmp/.initbroken
fi

# The file step 1 is about. It is valid, and says nothing yet.
cat > /etc/kubernetes/scheduler-config.yaml <<'YAML'
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
YAML

# /configz needs a client certificate. admin.conf carries one.
grep client-certificate-data /etc/kubernetes/admin.conf | awk '{print $2}' | base64 -d > /root/.configz.crt
grep client-key-data /etc/kubernetes/admin.conf | awk '{print $2}' | base64 -d > /root/.configz.key
chmod 600 /root/.configz.crt /root/.configz.key

# The scheduler's running configuration, with defaults applied. Not the file:
# what the process actually loaded. Compact JSON on one line so it can be
# grepped; with -p it is pretty-printed instead, when jq or python3 is there.
cat > /usr/local/bin/configz <<'WRAP'
#!/bin/bash
OUT=$(curl -sk --cert /root/.configz.crt --key /root/.configz.key https://127.0.0.1:10259/configz) \
  || { echo "The scheduler is not answering on 127.0.0.1:10259."; exit 1; }
[ -n "$OUT" ] || { echo "The scheduler is not answering on 127.0.0.1:10259."; exit 1; }
if [ "$1" == "-p" ]; then
  if command -v jq >/dev/null 2>&1; then echo "$OUT" | jq .
  elif command -v python3 >/dev/null 2>&1; then echo "$OUT" | python3 -m json.tool
  else echo "$OUT"; fi
else
  echo "$OUT"
fi
WRAP
chmod +x /usr/local/bin/configz

# Restarts the scheduler. The kubelet restarts a static Pod when its MANIFEST
# changes; it never looks at the config file the manifest points to. Taking the
# manifest away and putting it back UNCHANGED does not help for long: a static
# Pod's identity is a hash of its manifest, so the same manifest is the same Pod,
# and it inherits the same crash back-off. Every restart makes the next one
# slower, up to minutes. Changing a harmless annotation makes it a new Pod, with
# a fresh back-off, every time.
cat > /usr/local/bin/restart-scheduler <<'WRAP'
#!/bin/bash
M=/etc/kubernetes/manifests/kube-scheduler.yaml
[ -f "$M" ] || { echo "$M is missing."; exit 1; }
hash_of() {
  kubectl -n kube-system get pod -l component=kube-scheduler \
    -o jsonpath='{.items[0].metadata.annotations.kubernetes\.io/config\.hash}' 2>/dev/null
}
OLD=$(hash_of)
sed -i '/^    restarted-at: /d' "$M"
if grep -q '^  annotations:$' "$M"; then
  sed -i "s/^  annotations:\$/  annotations:\n    restarted-at: \"$(date +%s)\"/" "$M"
else
  sed -i "s/^metadata:\$/metadata:\n  annotations:\n    restarted-at: \"$(date +%s)\"/" "$M"
fi
for _ in $(seq 1 60); do
  NEW=$(hash_of)
  READY=$(kubectl -n kube-system get pod -l component=kube-scheduler -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  if [ -n "$NEW" ] && [ "$NEW" != "$OLD" ] && [ "$READY" == "true" ]; then
    echo "kube-scheduler is Ready."
    exit 0
  fi
  # A new Pod that has already crashed twice is not going to come up by waiting.
  RC=$(kubectl -n kube-system get pod -l component=kube-scheduler -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
  if [ -n "$NEW" ] && [ "$NEW" != "$OLD" ] && [ "${RC:-0}" -ge 2 ]; then
    break
  fi
  sleep 2
done
echo "kube-scheduler is not Ready:"
kubectl -n kube-system get pod -l component=kube-scheduler --no-headers
echo "What it last said:"
kubectl -n kube-system logs -l component=kube-scheduler --tail=3 2>/dev/null | cut -c1-240
exit 1
WRAP
chmod +x /usr/local/bin/restart-scheduler

# Plumbing the learner applies rather than writes. Same Pod spec, 12 replicas
# each, differing only in who is asked to place them. They land on the fake
# nodes, so there is nothing to pull and nothing to wait for.
for NAME in spread packed; do
  SCHED=default-scheduler; [ $NAME = packed ] && SCHED=bin-packing
  cat > /root/$NAME.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
spec:
  replicas: 12
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      schedulerName: $SCHED
      nodeSelector:
        type: kwok
      tolerations:
      - key: kwok.x-k8s.io/node
        operator: Exists
      containers:
      - name: c
        image: busybox:1.36
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
YAML
done

# One Pod that names no scheduler and one that names bin-packing, for the
# checks in steps 3 and 4 and for the learner to apply by hand. Fake nodes, so
# nothing to pull.
for NAME in plain packed-pod; do
  SCHED=""; [ $NAME = packed-pod ] && SCHED="schedulerName: bin-packing"
  cat > /root/$NAME.yaml <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: $NAME
spec:
  $SCHED
  nodeSelector:
    type: kwok
  tolerations:
  - key: kwok.x-k8s.io/node
    operator: Exists
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
YAML
done

# Step 3: a colleague's config. It is meant to ADD a bin-packing profile, and
# it carries the fix from step 2, so only one thing in it is wrong.
cat > /root/team-config.yaml <<'YAML'
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
percentageOfNodesToScore: 50
profiles:
- schedulerName: bin-packing
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated
        resources:
        - {name: cpu, weight: 1}
        - {name: memory, weight: 1}
  - name: PodTopologySpread
    args:
      defaultingType: List
      defaultConstraints: []
YAML

touch /tmp/.initfinished
