#!/bin/bash

echo "Dropping solar-system's manifests into /root/solar-system-app..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
