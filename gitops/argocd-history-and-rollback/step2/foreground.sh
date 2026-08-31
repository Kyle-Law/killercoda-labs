#!/bin/bash

echo "Rebuilding podinfo's history: replicaCount 1, then 2, then 3..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
