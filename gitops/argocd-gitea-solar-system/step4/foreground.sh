#!/bin/bash

echo "Redeploying solar-system from your Gitea repo, synced and healthy on v3..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
