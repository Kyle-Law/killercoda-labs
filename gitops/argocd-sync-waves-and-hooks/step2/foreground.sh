#!/bin/bash

echo "Redeploying sync-waves from a clean slate (give it a minute)..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
