#!/bin/bash

echo "Cleaning up the App-of-Apps example before starting ApplicationSet..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
