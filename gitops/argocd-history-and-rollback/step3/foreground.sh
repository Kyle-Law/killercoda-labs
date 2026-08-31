#!/bin/bash

echo "Rebuilding podinfo's history and rolling back to ID 0 (replicaCount=1)..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
