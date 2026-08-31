#!/bin/bash

echo "guestbook is Synced/Healthy, automated sync + self-heal already on..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done
echo "Ready. Good luck!"
