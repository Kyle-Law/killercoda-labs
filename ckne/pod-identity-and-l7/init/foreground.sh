#!/bin/bash

echo -n "Starting api and web..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
