#!/bin/bash

echo "Resetting kustomize-guestbook to a clean, default sync..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
