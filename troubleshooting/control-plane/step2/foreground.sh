#!/bin/bash

echo "Breaking the kube-controller-manager..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
