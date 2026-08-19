#!/bin/bash

echo "Creating a ServiceAccount and a Role..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done
echo "Ready. Good luck!"
