#!/bin/bash

echo "Installing podinfo-values4, and dropping a release-notes file in /root..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
