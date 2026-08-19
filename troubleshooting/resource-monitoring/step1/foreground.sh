#!/bin/bash

echo "Deploying two Pods with different loads..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done

# give metrics-server a scrape interval to pick both of them up
for i in $(seq 1 30); do
  COUNT=$(kubectl top pod low-cpu high-cpu --no-headers 2>/dev/null | wc -l)
  [ "$COUNT" -ge 2 ] && break
  sleep 5
done

echo "Ready. Good luck!"
