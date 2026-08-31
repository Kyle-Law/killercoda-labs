#!/bin/bash

echo "Redeploying sync-waves fresh, one more time (give it a minute)..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
