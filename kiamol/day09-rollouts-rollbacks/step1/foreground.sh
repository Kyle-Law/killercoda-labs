#!/bin/bash

echo "Deploying web through 3 releases..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done
echo "Ready. Good luck!"
