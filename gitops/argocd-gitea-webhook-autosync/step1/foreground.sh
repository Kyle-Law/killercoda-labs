#!/bin/bash

echo "Installing Argo CD and Gitea, both on NodePort, and dropping solar-system's manifests into /root/solar-system-app..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done
echo "Ready. Good luck!"
