#!/bin/bash

echo -n "Starting api, web, a scanner nobody authorised, and a client..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
