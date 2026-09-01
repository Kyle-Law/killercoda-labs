#!/bin/bash

echo "Installing Argo CD Core..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done
echo "Ready. Good luck!"
