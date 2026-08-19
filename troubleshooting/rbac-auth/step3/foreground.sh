#!/bin/bash

echo "Creating a ServiceAccount, ClusterRole, and a binding..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
