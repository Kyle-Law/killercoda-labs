#!/bin/bash

echo "Deploying a Pod..."
while [ ! -f /tmp/step4-ready ]; do sleep 1; done
echo "Ready. Good luck!"
