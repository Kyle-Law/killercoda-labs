#!/bin/bash

echo "Deploying StatefulSet web..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get statefulset web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 2
done

kubectl get pod web-0 -o jsonpath='{.metadata.uid}' > /root/original-web0-uid.txt

echo "Ready. Good luck!"
