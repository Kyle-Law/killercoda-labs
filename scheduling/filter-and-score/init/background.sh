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

# /configz needs a client certificate. admin.conf carries one.
grep client-certificate-data /etc/kubernetes/admin.conf | awk '{print $2}' | base64 -d > /root/.configz.crt
grep client-key-data /etc/kubernetes/admin.conf | awk '{print $2}' | base64 -d > /root/.configz.key
chmod 600 /root/.configz.crt /root/.configz.key

# The scheduler's running configuration, defaults applied, as one line of JSON
# so it can be grepped. configz -p pretty-prints it when jq or python3 is there.
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

# Restarts the scheduler as a NEW Pod. A static Pod's identity is a hash of its
# manifest, so taking the manifest away and putting it back unchanged returns
# the same Pod with the crash back-off it had already built up. Changing a
# harmless annotation gives a fresh one every time.
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

# The cluster can still be coming up when this runs.
for _ in $(seq 1 60); do
  kubectl get nodes >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null 2>&1

# The static Pod manifest as kubeadm wrote it, and as this lab leaves it.
cp /etc/kubernetes/manifests/kube-scheduler.yaml /root/kube-scheduler.yaml.orig

# Fake nodes: this is scheduling/kwok-nodes.sh, verbatim.
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
KWOKEOF
chmod +x /root/kwok-nodes.sh
bash /root/kwok-nodes.sh 12 >/dev/null 2>&1
if [ "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)" -lt 12 ]; then
  touch /tmp/.initbroken
fi

# The scheduler reads a config file, as it does at the end of scheduler-profiles.
# Step 4's fix is a setting in that file.
cat > /etc/kubernetes/scheduler-config.yaml <<'YAML'
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
YAML
M=/etc/kubernetes/manifests/kube-scheduler.yaml
sed -i 's|^    - kube-scheduler$|    - kube-scheduler\n    - --config=/etc/kubernetes/scheduler-config.yaml|' $M
sed -i '/^    volumeMounts:$/a\    - mountPath: /etc/kubernetes/scheduler-config.yaml\n      name: config\n      readOnly: true' $M
sed -i '/^  volumes:$/a\  - hostPath:\n      path: /etc/kubernetes/scheduler-config.yaml\n      type: File\n    name: config' $M
restart-scheduler >/dev/null 2>&1
cp $M /root/kube-scheduler.yaml.start

# Step 1's fleet. Twelve fake nodes, broken in different ways, and a Pod that
# fits none of them.
#
#   nodes 0,1,2     tainted dedicated=batch, and full
#   nodes 3,4,5     tainted, and missing the tier=gold label
#   nodes 6,7       full
#   nodes 8,9       missing the tier=gold label
#   nodes 10,11     tainted, full, and missing the label
#
# "Full" is a filler Pod asking for 7500m of an 8 CPU node.
for i in 0 1 2 3 4 5 10 11; do kubectl taint node kwok-node-$i dedicated=batch:NoSchedule >/dev/null 2>&1; done
for i in 0 1 2 6 7; do kubectl label node kwok-node-$i tier=gold >/dev/null 2>&1; done
for i in 0 1 2 6 7 10 11; do
  cat <<YAML | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: filler-$i
  labels:
    role: filler
spec:
  nodeName: kwok-node-$i
  tolerations:
  - operator: Exists
  containers:
  - name: c
    image: busybox:1.36
    resources:
      requests:
        cpu: 7500m
YAML
done

cat > /root/job.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: job
spec:
  nodeSelector:
    type: kwok
    tier: gold
  tolerations:
  - key: kwok.x-k8s.io/node
    operator: Exists
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "1"
YAML
kubectl apply -f /root/job.yaml >/dev/null 2>&1

# Step 2: a Pod with no opinions, so the scores are about the nodes.
cat > /root/scored.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: scored
spec:
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
        cpu: 100m
YAML

# Steps 3 and 4: replicas that prefer the node labelled tier=gold, with weight 100
# (the most a preference can have).
for NAME in seekers seekers20; do
  REPL=6; [ $NAME = seekers20 ] && REPL=20
  cat > /root/$NAME.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
spec:
  replicas: $REPL
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      nodeSelector:
        type: kwok
      tolerations:
      - key: kwok.x-k8s.io/node
        operator: Exists
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: tier
                operator: In
                values: ["gold"]
      containers:
      - name: c
        image: busybox:1.36
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 100m
YAML
done

# Puts the fake nodes back to a clean state: N of them (default 12), nothing on
# them, nothing tainted, and kwok-node-5 labelled tier=gold. Deleting by label is
# fast; creating them is not, because each new node keeps a not-ready taint until
# the node lifecycle controller clears it, about five a second.
cat > /usr/local/bin/reset-nodes <<'WRAP'
#!/bin/bash
N=${1:-12}
kubectl delete deployment seekers seekers20 --ignore-not-found --now >/dev/null 2>&1
kubectl delete pod job scored plain --ignore-not-found --now >/dev/null 2>&1
kubectl delete pods -l role=filler --now >/dev/null 2>&1
kubectl delete nodes -l type=kwok --wait=false >/dev/null 2>&1
while [ "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l)" -gt 0 ]; do sleep 0.5; done
[ "$N" -gt 100 ] && echo "Creating $N fake nodes. The last of them are not schedulable for about $((N / 5)) seconds; this waits for that."
bash /root/kwok-nodes.sh "$N" || exit 1
kubectl label node kwok-node-5 tier=gold --overwrite >/dev/null
echo "$N clean fake nodes. kwok-node-5 is labelled tier=gold."
WRAP
chmod +x /usr/local/bin/reset-nodes

# What each plugin scored each node, for one Pod, from the scheduler's own log.
# Needs the scheduler to be logging scores, which is step 2.
cat > /usr/local/bin/scores <<'WRAP'
#!/bin/bash
POD=$1; NODE=$2
[ -n "$POD" ] || { echo "usage: scores <pod> [node]"; exit 1; }
OUT=$(kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 2>/dev/null \
  | grep "pod=\"default/$POD\"" | grep -E 'Plugin scored node for pod|Calculated node.s final score' \
  | sed -E 's/^.*(Plugin scored node for pod|Calculated node.s final score for pod)" pod="[^"]*"( plugin="([A-Za-z]+)")? node="([^"]*)" score=([0-9]+).*$/\4 \3 \5/' \
  | sed -E 's/^([^ ]+)  ([0-9]+)$/\1 TOTAL \2/; s/^([^ ]+) +([0-9]+)$/\1 TOTAL \2/')
if [ -z "$OUT" ]; then
  echo "The scheduler's log has no scores for '$POD'."
  echo "Either it has not been scheduled, or the scheduler is not logging scores."
  exit 1
fi
if [ -n "$NODE" ]; then echo "$OUT" | grep "^$NODE "; else echo "$OUT" | sort; fi
WRAP
chmod +x /usr/local/bin/scores

touch /tmp/.initfinished
