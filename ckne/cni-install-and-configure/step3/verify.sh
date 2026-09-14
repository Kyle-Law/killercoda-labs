#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · The other half of the contract"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The plugin binary named by the conflist has to be back where the kubelet
# looks for it -- leaving the node in the broken state is the one way to
# finish this step wrong.
[ -x /opt/cni/bin/cilium-cni ] || fail \
  "/opt/cni/bin/cilium-cni is missing or not executable." \
  "" \
  "The conflist names a binary; without it the kubelet has half a contract and" \
  "every new Pod fails to be wired up. Put it back -- the agent ships a copy and" \
  "reinstalls it on start:" \
  "  ls -l /opt/cni/bin/" \
  "  kubectl -n kube-system delete pod -l k8s-app=cilium" \
  "  ls -l /opt/cni/bin/"

# Cilium's own config must be the one in force, not a leftover from step 1.
[ -f /etc/cni/net.d/05-cilium.conflist ] || fail \
  "/etc/cni/net.d/05-cilium.conflist is not there." \
  "" \
  "Cilium writes its own conflist when its agent starts. If it is missing, the" \
  "agent has not run since the directory was last touched:" \
  "  ls -l /etc/cni/net.d/" \
  "  kubectl -n kube-system get pods -l k8s-app=cilium"

OTHER=$(ls /etc/cni/net.d/*.conflist 2>/dev/null | grep -v '05-cilium.conflist')
[ -n "$OTHER" ] && fail \
  "Another conflist is still in /etc/cni/net.d: $(echo $OTHER | tr '\n' ' ')" \
  "" \
  "The kubelet picks the lowest-numbered file in that directory, so a leftover" \
  "from step 1 can quietly win and wire Pods up with the wrong plugin. Leave" \
  "exactly one:" \
  "  ls -l /etc/cni/net.d/"

# And the proof that the restored binary works: a Pod that can be created now.
kubectl delete pod cniprobe --ignore-not-found --wait=true >/dev/null 2>&1
kubectl run cniprobe --image=registry.k8s.io/e2e-test-images/agnhost:2.53 \
  --command -- /bin/sh -c "sleep 300" >/dev/null 2>&1

for _ in $(seq 1 24); do
  IP=$(kubectl get pod cniprobe -o jsonpath='{.status.podIP}' 2>/dev/null)
  PHASE=$(kubectl get pod cniprobe -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$PHASE" == "Running" ] && [ -n "$IP" ]; then
    kubectl delete pod cniprobe --wait=false >/dev/null 2>&1
    pass
  fi
  sleep 5
done

EVENTS=$(kubectl describe pod cniprobe 2>/dev/null | grep -iE 'failed|error' | tail -3)
kubectl delete pod cniprobe --wait=false >/dev/null 2>&1
fail \
  "Both files are in place, but a freshly created Pod still does not get an address." \
  "" \
  "  test Pod phase:    ${PHASE:-<none>}" \
  "  test Pod address:  ${IP:-<none>}" \
  "" \
  "What the kubelet said about it:" \
  "  ${EVENTS:-<nothing recorded>}" \
  "" \
  "containerd caches the parsed CNI configuration, so a file that is correct on" \
  "disk is not necessarily the one in use:" \
  "  systemctl restart containerd"
