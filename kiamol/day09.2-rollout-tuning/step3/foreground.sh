#!/bin/bash

echo "Putting history-app through five releases..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  RS_COUNT=$(kubectl get rs -l app=history-app --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$RS_COUNT" == "5" ] && break
  sleep 2
done

echo "Ready. Good luck!"
