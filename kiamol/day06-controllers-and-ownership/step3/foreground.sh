#!/bin/bash

echo "Deploying node-agent DaemonSet..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  READY=$(kubectl get daemonset node-agent -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [ "$READY" == "1" ] && break
  sleep 2
done

echo "Ready. Good luck!"
