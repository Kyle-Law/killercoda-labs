#!/bin/bash

echo "Setting up a blue-green Rollout (active + preview Services)..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
