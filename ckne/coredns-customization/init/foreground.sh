#!/bin/bash

echo -n "Starting web, a corporate resolver, and a DNS client..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
