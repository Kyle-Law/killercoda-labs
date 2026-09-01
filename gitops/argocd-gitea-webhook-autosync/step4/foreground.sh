#!/bin/bash

echo "Ready for auto-prune..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
