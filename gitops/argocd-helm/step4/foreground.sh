#!/bin/bash

echo "Setting up podinfo-helm (chart-repo source) and helm-guestbook (Git-sourced chart)..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
