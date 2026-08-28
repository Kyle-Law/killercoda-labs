#!/bin/bash

echo -n "Initialising scenario..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
