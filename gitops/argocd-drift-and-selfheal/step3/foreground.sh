#!/bin/bash

echo "Resetting guestbook to Synced/Healthy with manual sync policy..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
