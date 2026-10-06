#!/bin/bash
LOG=/root/.check
STEP="Step 3 · Be the scheduler in a loop"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

kubectl get deployment web >/dev/null 2>&1 || fail \
  "There is no Deployment called 'web'." \
  "" \
  "Apply the one you were given:" \
  "  kubectl apply -f /root/web.yaml"

SCHED=$(kubectl get deployment web -o jsonpath='{.spec.template.spec.schedulerName}' 2>/dev/null)
[ "$SCHED" == "by-hand" ] || fail \
  "'web' no longer names schedulerName: by-hand (it says: ${SCHED:-<unset>})." \
  "" \
  "The default scheduler would place those Pods for you, and the point is that" \
  "you do. Put it back:  kubectl apply -f /root/web.yaml"

R=""
for _ in $(seq 1 12); do
  RUNNING=$(kubectl get pods -l app=web --no-headers 2>/dev/null | awk '$3=="Running"' | wc -l)
  [ "$RUNNING" -ge 3 ] || { R="web"; sleep 5; continue; }
  R=""; break
done

if [ "$R" == "web" ]; then
  PEND=$(kubectl get pods -l app=web --no-headers 2>/dev/null | awk '$3=="Pending"' | wc -l)
  fail \
    "Only $RUNNING of the 3 'web' Pods are Running ($PEND Pending)." \
    "" \
    "  kubectl get pods -l app=web -o wide" \
    "" \
    "A Pending 'web' Pod has no node, and the only thing that gives it one is your" \
    "loop. Is it still running?   pgrep -af by-hand" \
    "Is it printing errors?       cat /root/by-hand.log"
fi

# The Pods above might have been placed an hour ago. This proves the loop is
# alive now: a Pod created after the fact has to be bound without any help.
kubectl delete pod probe --now --ignore-not-found >/dev/null 2>&1
cat <<'YAML' | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: probe
spec:
  schedulerName: by-hand
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
  "The 'web' Pods are Running, but your scheduler is not running now." \
  "" \
  "A new Pod that names 'by-hand' was created and nothing gave it a node within" \
  "30 seconds. The loop has stopped, or was never left running in the background:" \
  "  pgrep -af by-hand" \
  "  cat /root/by-hand.log"

pass
