#!/bin/bash

echo "Installing a healthy podinfo3 release..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
