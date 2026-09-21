#!/bin/bash

echo -n "Installing cert-manager and trust-manager..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"

if [ -f /tmp/.initbroken ]; then
  echo
  echo "!! cert-manager did not install cleanly. Nothing in this lab will work."
  echo "!! Check with:  kubectl -n cert-manager get pods"
fi
echo
