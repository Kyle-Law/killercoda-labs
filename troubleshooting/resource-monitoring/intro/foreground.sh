#!/bin/bash

echo "Installing metrics-server..."
while [ ! -f /tmp/intro-applied ]; do sleep 1; done

for i in $(seq 1 60); do
  kubectl top nodes >/dev/null 2>&1 && break
  sleep 5
done

echo "Ready. Good luck!"
