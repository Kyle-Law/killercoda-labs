#!/bin/bash

echo "Deploying db StatefulSet with a failing readiness probe..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  kubectl get pod db-0 >/dev/null 2>&1 && break
  sleep 2
done

echo "Ready. Good luck!"
