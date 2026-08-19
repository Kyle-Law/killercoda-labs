#!/bin/bash

echo "Breaking the kube-scheduler..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get pods -n kube-system -l component=kube-scheduler -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "false" ] && break
  sleep 2
done

echo "Ready. Good luck!"
