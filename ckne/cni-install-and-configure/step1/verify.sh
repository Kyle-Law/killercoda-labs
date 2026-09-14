#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · A node with no pod network"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The task was explicitly to do this without installing CNI software, so a
# DaemonSet mounting the config directory means the point was skipped rather
# than made.
CNI_DS=$(kubectl get ds -A -o jsonpath='{range .items[*]}{.metadata.name}{range .spec.template.spec.volumes[*]}{" "}{.hostPath.path}{end}{"\n"}{end}' 2>/dev/null \
  | awk '/\/etc\/cni/ {print $1}')
[ -n "$CNI_DS" ] && fail \
  "A CNI DaemonSet is running again: $(echo $CNI_DS | tr '\n' ' ')" \
  "" \
  "This step asks for the opposite -- a pod network with no CNI software at all," \
  "written by hand. Installing one skips the thing the step is about. Remove it" \
  "and write /etc/cni/net.d yourself; step 2 is where a real CNI goes on."

# A network configuration has to actually be on disk for the kubelet to read.
[ -z "$(ls -A /etc/cni/net.d 2>/dev/null)" ] && fail \
  "/etc/cni/net.d is empty, so the kubelet has no network configuration to read." \
  "" \
  "The CNI contract is two files: a plugin binary in /opt/cni/bin and a JSON" \
  "conflist in /etc/cni/net.d naming it. Both already exist on this node except" \
  "the conflist -- write one:" \
  "  ls /opt/cni/bin" \
  "  ls -l /etc/cni/net.d"

for _ in $(seq 1 24); do
  READY=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

  # Ready on its own is not enough -- the claim is that Pods now get addresses,
  # so require a real workload running with one.
  IP=$(kubectl get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)

  if [ "$READY" == "True" ] && [ -n "$IP" ]; then
    pass
  fi
  sleep 5
done

PHASE=$(kubectl get pods -l app=web -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
fail \
  "A configuration is on disk, but the node and a running Pod have not both arrived." \
  "" \
  "  node Ready:        ${READY:-<unknown>}" \
  "  web Pod phase:     ${PHASE:-<none>}" \
  "  web Pod address:   ${IP:-<none>}" \
  "" \
  "Node NotReady means the kubelet is still refusing the config -- read what it" \
  "objects to, then remember containerd caches the parsed config and has to be" \
  "restarted after a change:" \
  "  kubectl describe node | grep -A3 NetworkReady" \
  "  systemctl restart containerd" \
  "" \
  "Pending rather than ContainerCreating is expected while the node is NotReady:" \
  "it is tainted NoSchedule, so nothing can land on it until the network is up." \
  "Pods created during the outage may need deleting so they are scheduled again:" \
  "  kubectl get pods -o wide"
