#!/bin/bash

echo "Installing Argo Rollouts and its first canary Rollout..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  kubectl-argo-rollouts version >/dev/null 2>&1 && break
  sleep 2
done

echo "Ready. Good luck!"
