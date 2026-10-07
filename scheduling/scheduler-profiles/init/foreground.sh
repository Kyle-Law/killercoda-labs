#!/bin/bash

echo -n "Preparing the cluster and twelve fake nodes..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"

if [ -f /tmp/.initbroken ]; then
  echo
  echo "!! The fake nodes did not all come up. Steps 2 and 3 will not work."
  echo "!! Check with:  kubectl get nodes -l type=kwok"
fi
echo
