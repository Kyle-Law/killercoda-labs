#!/bin/bash

echo "Installing podinfo-values3 at revision 1, then upgrading to revision 2 (replicaCount=2 via --set)..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
