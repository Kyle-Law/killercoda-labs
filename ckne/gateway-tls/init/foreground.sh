#!/bin/bash

echo -n "Installing Envoy Gateway, cert-manager, and a self-signed root CA..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
