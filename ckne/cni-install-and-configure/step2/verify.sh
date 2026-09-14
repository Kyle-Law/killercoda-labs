#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · Addresses are not a network"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# A real CNI, installed and running.
for _ in $(seq 1 24); do
  DESIRED=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  READY=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [ -n "$DESIRED" ] && [ "$DESIRED" != "0" ] && [ "$DESIRED" == "$READY" ] && break
  sleep 5
done
[ -n "$DESIRED" ] && [ "$DESIRED" == "$READY" ] || fail \
  "The 'cilium' DaemonSet is not running on every node (ready ${READY:-0} of ${DESIRED:-0})." \
  "" \
  "Install it with the pinned version the lab uses, and wait for it:" \
  "  kubectl -n kube-system get pods -l k8s-app=cilium" \
  "  kubectl -n kube-system describe ds cilium | tail -20"

# The demonstration is only finished once the policy has been taken off again.
kubectl get netpol deny-all-to-web >/dev/null 2>&1 && fail \
  "The 'deny-all-to-web' policy is still in force." \
  "" \
  "It was there to show that a CNI does more than hand out addresses. Leaving it" \
  "on would make every later step measure the policy instead of the datapath:" \
  "  kubectl delete netpol deny-all-to-web"

# web must be running and managed by Cilium -- an endpoint exists only for a
# Pod that Cilium itself set up, which is what the recreation step was for.
for _ in $(seq 1 24); do
  IP=$(kubectl get pods -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
  if [ -n "$IP" ]; then
    kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
      cilium-dbg endpoint list 2>/dev/null | grep -q "$IP" && pass
  fi
  sleep 5
done

fail \
  "Cilium is running, but 'web' is not one of its endpoints (address: ${IP:-<none>})." \
  "" \
  "A Pod keeps the network the plugin that created it gave it. web was wired up" \
  "by the hand-written config from step 1, so Cilium knows nothing about it and" \
  "cannot enforce anything on it. Recreate it so the new plugin sets it up:" \
  "  kubectl delete pod -l app=web" \
  "  kubectl get pods -l app=web -o wide" \
  "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg endpoint list"
