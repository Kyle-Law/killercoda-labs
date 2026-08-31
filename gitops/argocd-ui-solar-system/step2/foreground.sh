#!/bin/bash

echo "Clearing any previous solar-system Application..."
while [ ! -f /tmp/step2-applied ]; do sleep 1; done
echo "Ready. Good luck!"
