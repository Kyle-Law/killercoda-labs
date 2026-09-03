#!/bin/bash

kubectl get deployment fails-liveness >/dev/null 2>&1 || exit 1
kubectl get deployment fails-readiness >/dev/null 2>&1 || exit 1

# Each Deployment has to be broken the intended way, and watched by the
# matching probe -- otherwise the contrast being demonstrated isn't there.
L_CMD=$(kubectl get deployment fails-liveness -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$L_CMD" | grep -q -- "--unhealthy" || exit 1
L_PROBE=$(kubectl get deployment fails-liveness -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' 2>/dev/null)
[ -n "$L_PROBE" ] || exit 1

R_CMD=$(kubectl get deployment fails-readiness -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$R_CMD" | grep -q -- "--unready" || exit 1
R_PROBE=$(kubectl get deployment fails-readiness -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
[ -n "$R_PROBE" ] || exit 1

for i in $(seq 1 30); do
  # Liveness failure => the kubelet keeps killing it.
  L_RESTARTS=$(kubectl get pods -l app=fails-liveness \
    -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)

  # Readiness failure => never restarted, still Running, just not Ready.
  R_RESTARTS=$(kubectl get pods -l app=fails-readiness \
    -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
  R_PHASE=$(kubectl get pods -l app=fails-readiness \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  R_READY=$(kubectl get pods -l app=fails-readiness \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)

  if [ -n "$L_RESTARTS" ] && [ "$L_RESTARTS" -ge 2 ] 2>/dev/null \
     && [ "$R_RESTARTS" == "0" ] && [ "$R_PHASE" == "Running" ] && [ "$R_READY" == "false" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
