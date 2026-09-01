#!/bin/bash

echo "Ready for self-heal..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done
echo "Ready. Good luck!"
