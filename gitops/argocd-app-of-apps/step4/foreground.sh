#!/bin/bash

echo "Cleaning up the list-generator example before starting the git-directory one..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
