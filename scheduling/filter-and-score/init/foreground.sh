#!/bin/bash

echo -n "Preparing twelve fake nodes, a scheduler that reads a config file, and a Pod that fits none of them..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"

if [ -f /tmp/.initbroken ]; then
  echo
  echo "!! The fake nodes did not all come up. Nothing in this lab will work."
  echo "!! Check with:  kubectl get nodes -l type=kwok"
fi
echo
