#!/bin/bash

echo -n "Starting web, its Service, and a client Pod..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
