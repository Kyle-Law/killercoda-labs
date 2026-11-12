#!/bin/bash

echo -n "Preparing the cluster..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"

if [ -f /tmp/.initbroken ]; then
  echo
  echo "!! The chat Deployment or the cli Pod did not become Ready. Nothing in this lab will work."
  echo "!! Check with:  kubectl -n serve get pods"
fi
echo
