#!/bin/bash

echo "Installing Helm and a healthy podinfo-values1 release..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  helm version >/dev/null 2>&1 && break
  sleep 2
done

echo "Ready. Good luck!"
