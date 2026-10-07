#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · Two failures, both \"the file is right there\""
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

M=/etc/kubernetes/manifests/kube-scheduler.yaml

# What the scheduler last said, for the failure messages. A crashing Pod only
# yields its log from the previous container.
last_error() {
  { kubectl -n kube-system logs -l component=kube-scheduler --tail=30 2>/dev/null
    kubectl -n kube-system logs -l component=kube-scheduler --previous --tail=30 2>/dev/null; } \
    | grep -E '^E' | grep -v 'broadcaster already stopped' | tail -1 | cut -c1-260
}

grep -q -- '--config=/etc/kubernetes/scheduler-config.yaml' "$M" || fail \
  "The scheduler is not being told to read /etc/kubernetes/scheduler-config.yaml." \
  "" \
  "Its manifest has no --config flag naming that file:" \
  "  grep -n -A8 'command:' $M"

READY=""
for _ in $(seq 1 18); do
  READY=$(kubectl -n kube-system get pod -l component=kube-scheduler \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] && break
  sleep 5
done

if [ "$READY" != "true" ]; then
  fail \
    "kube-scheduler is not Ready." \
    "" \
    "  $(kubectl -n kube-system get pod -l component=kube-scheduler --no-headers 2>/dev/null | awk '{print $1, $2, $3, "restarts="$4}')" \
    "" \
    "What it last said:" \
    "  $(last_error)" \
    "" \
    "  kubectl -n kube-system logs -l component=kube-scheduler --tail=20" \
    "" \
    "If you changed only the config file, nothing restarted the scheduler:  restart-scheduler"
fi

# A Pod created after the fact has to be given a node with no help. Fake nodes,
# so there is nothing to pull.
kubectl delete pod probe --now --ignore-not-found >/dev/null 2>&1
cat <<'YAML' | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: probe
spec:
  nodeSelector:
    type: kwok
  tolerations:
  - key: kwok.x-k8s.io/node
    operator: Exists
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "60"]
YAML
BOUND=""
for _ in $(seq 1 10); do
  BOUND=$(kubectl get pod probe -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  [ -n "$BOUND" ] && break
  sleep 3
done
kubectl delete pod probe --now --wait=false >/dev/null 2>&1

[ -n "$BOUND" ] || fail \
  "kube-scheduler is Ready, but a new Pod was not given a node within 30 seconds." \
  "" \
  "  kubectl -n kube-system logs -l component=kube-scheduler --tail=20" \
  "" \
  "Is it the scheduler you are expecting, running with your file?" \
  "  kubectl -n kube-system get pod -l component=kube-scheduler -o jsonpath='{.items[0].spec.containers[0].command}'"

pass
