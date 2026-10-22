#!/bin/bash

echo -n "Preparing the cluster..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"

if [ -f /tmp/.initbroken ]; then
  echo
  echo "!! The web Pod did not become Ready. Nothing in this lab will work."
  echo "!! Check with:  kubectl -n rb get pods"
fi
echo
