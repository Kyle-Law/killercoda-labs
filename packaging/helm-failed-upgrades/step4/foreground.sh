#!/bin/bash

echo "Installing podinfo4 at revision 1, then upgrading to revision 2 (2 replicas)..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
