#!/bin/bash

echo "Installing a healthy podinfo2 release..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
