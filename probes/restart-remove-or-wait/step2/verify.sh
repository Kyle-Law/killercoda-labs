#!/bin/bash

C='{.spec.template.spec.containers[0]}'

kubectl get deployment slow-starter >/dev/null 2>&1 || exit 1

# Still the same slow app -- the fix has to be in the probes, not the workload.
CMD=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].command}" 2>/dev/null)
echo "$CMD" | grep -q "sleep 60" || exit 1

# A startup probe must be doing the waiting.
STARTUP=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].startupProbe}" 2>/dev/null)
[ -n "$STARTUP" ] || exit 1

# The startup budget must actually cover the 60s boot.
S_PERIOD=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].startupProbe.periodSeconds}" 2>/dev/null)
S_THRESH=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].startupProbe.failureThreshold}" 2>/dev/null)
[ -n "$S_PERIOD" ] || S_PERIOD=10
[ -n "$S_THRESH" ] || S_THRESH=3
[ $((S_PERIOD * S_THRESH)) -ge 70 ] || exit 1

# Liveness must be back...
LIVENESS=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].livenessProbe}" 2>/dev/null)
[ -n "$LIVENESS" ] || exit 1

# ...and must be tight, not hiding behind a long initialDelaySeconds.
L_DELAY=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].livenessProbe.initialDelaySeconds}" 2>/dev/null)
[ -n "$L_DELAY" ] || L_DELAY=0
[ "$L_DELAY" -le 15 ] || exit 1

L_PERIOD=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].livenessProbe.periodSeconds}" 2>/dev/null)
L_THRESH=$(kubectl get deployment slow-starter -o jsonpath="{.spec.template.spec.containers[0].livenessProbe.failureThreshold}" 2>/dev/null)
[ -n "$L_PERIOD" ] || L_PERIOD=10
[ -n "$L_THRESH" ] || L_THRESH=3
[ $((L_DELAY + L_PERIOD * L_THRESH)) -le 30 ] || exit 1

# And the Pod must survive its whole startup without a single restart.
for i in $(seq 1 40); do
  READY=$(kubectl get deployment slow-starter -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ "$READY" == "1" ]; then
    RESTARTS=$(kubectl get pods -l app=slow-starter -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
    [ "$RESTARTS" == "0" ] && exit 0
  fi
  sleep 5
done

exit 1
