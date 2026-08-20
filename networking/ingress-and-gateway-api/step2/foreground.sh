#!/bin/bash

echo "Installing Gateway API CRDs..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 && break
  sleep 3
done

echo "Ready. Good luck!"
