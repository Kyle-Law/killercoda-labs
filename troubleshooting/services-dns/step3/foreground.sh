#!/bin/bash

echo "Breaking CoreDNS..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  READY=$(kubectl -n kube-system get deployment coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ -z "$READY" ] || [ "$READY" == "0" ]; then break; fi
  sleep 2
done

echo "Ready. Good luck!"
