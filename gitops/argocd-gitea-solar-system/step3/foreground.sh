#!/bin/bash

echo "Clearing any previous solar-system Application..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
