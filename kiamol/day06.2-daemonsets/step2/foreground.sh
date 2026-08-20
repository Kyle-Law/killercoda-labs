#!/bin/bash

echo "Tainting a node..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
