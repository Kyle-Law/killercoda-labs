#!/bin/bash

echo "Resetting solar-system to Synced/Healthy on v3, manual sync policy..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
