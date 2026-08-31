#!/bin/bash

echo "Resetting kustomize-guestbook to a clean, default sync..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
