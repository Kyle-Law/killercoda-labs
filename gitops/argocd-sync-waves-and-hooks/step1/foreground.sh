#!/bin/bash

echo "Installing Argo CD Core and syncing the sync-waves example app (this has several deliberate sleeps, give it a minute)..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  argocd version --client >/dev/null 2>&1 && break
  sleep 2
done

echo "Ready. Good luck!"
