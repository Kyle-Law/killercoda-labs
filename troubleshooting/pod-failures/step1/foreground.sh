#!/bin/bash

echo "Deploying a Pod..."
while [ ! -f /tmp/step1-ready ]; do sleep 1; done
echo "Ready. Good luck!"
