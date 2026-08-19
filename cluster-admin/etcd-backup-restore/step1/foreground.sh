#!/bin/bash

echo "Preparing etcdctl and a ConfigMap to protect..."
while [ ! -f /tmp/step1-applied ]; do sleep 1; done
echo "Ready. Good luck!"
