#!/bin/bash

echo "Deploying two more Pods..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  COUNT=$(kubectl top pod mem-hog mem-light --no-headers 2>/dev/null | wc -l)
  [ "$COUNT" -ge 2 ] && break
  sleep 5
done

echo "Ready. Good luck!"
