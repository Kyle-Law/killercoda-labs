#!/bin/bash

echo "Installing Argo CD (full install, UI included) across both nodes..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done
echo "Ready. Good luck!"
