#!/bin/bash

echo "Resetting app-of-apps to a clean two-child sync..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
