#!/bin/bash

echo "Resetting rollouts-demo to a clean, healthy first deploy..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
