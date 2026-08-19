#!/bin/bash

echo "Deploying a namespace with a ResourceQuota..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
sleep 5
echo "Ready. Good luck!"
