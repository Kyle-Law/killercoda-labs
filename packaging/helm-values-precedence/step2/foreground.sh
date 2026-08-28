#!/bin/bash

echo "Installing podinfo-values2, and dropping two conflicting values files in /root..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
