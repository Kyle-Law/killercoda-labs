#!/bin/bash

echo -n "Setting up /root/app with a base and a dev overlay..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
