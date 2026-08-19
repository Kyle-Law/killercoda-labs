#!/bin/bash

echo "Creating a ServiceAccount, Role, and RoleBinding..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
