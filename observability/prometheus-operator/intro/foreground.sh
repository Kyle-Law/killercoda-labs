#!/bin/bash

echo "Installing the Prometheus Operator bundle (10 CRDs + controller) - this takes a few minutes..."
while [ ! -f /tmp/intro-applied ]; do sleep 1; done

for i in $(seq 1 60); do
  READY=$(kubectl get deployment prometheus-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "1" ] && break
  sleep 5
done

echo "Ready. Good luck!"
