#!/bin/bash

echo "Deploying a Pod..."
while [ ! -f /tmp/step2-ready ]; do sleep 1; done
echo "Ready. Good luck!"
