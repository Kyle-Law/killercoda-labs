#!/bin/bash

echo -n "Installing Envoy Gateway and starting two backends..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
