#!/bin/bash

echo "Resetting podinfo-helm to a clean, default sync..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
