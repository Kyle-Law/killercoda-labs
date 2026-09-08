#!/bin/bash

echo -n "Starting web and api in the shop namespace..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
