#!/bin/bash

echo -n "Preparing the cluster..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"

if [ -f /tmp/.initbroken ]; then
  echo
  echo "!! No worker node was found. Nothing in this lab will work."
  echo "!! Check with:  kubectl get nodes"
fi
echo
