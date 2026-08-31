#!/bin/bash

echo "Redeploying solar-system, synced and healthy on v3..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
