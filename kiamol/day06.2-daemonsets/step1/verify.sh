#!/bin/bash

KIND=$(kubectl get daemonset log-agent -o jsonpath='{.kind}' 2>/dev/null)
[ "$KIND" == "DaemonSet" ] || exit 1

kubectl get daemonset log-agent -o yaml | grep -q "hostPath:" || exit 1
kubectl get daemonset log-agent -o yaml | grep -q "path: /var/log" || exit 1

for i in $(seq 1 6); do
  DESIRED=$(kubectl get daemonset log-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  READY=$(kubectl get daemonset log-agent -o jsonpath='{.status.numberReady}' 2>/dev/null)
  if [ -n "$DESIRED" ] && [ "$DESIRED" == "$READY" ] && [ "$DESIRED" -ge 1 ] 2>/dev/null; then
    exit 0
  fi
  sleep 5
done

exit 1
