#!/bin/bash

echo "Installing ingress-nginx (this pulls an image and runs an admission-webhook setup Job - can take a couple of minutes)..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 36); do
  READY=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "1" ] && break
  sleep 5
done

echo "Ready. Good luck!"
