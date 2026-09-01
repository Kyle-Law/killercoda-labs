#!/bin/bash

echo "Ready for the webhook..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
