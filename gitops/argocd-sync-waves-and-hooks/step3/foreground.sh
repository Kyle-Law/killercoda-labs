#!/bin/bash

echo "Preparing the pre-post-sync example app (not yet synced)..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
