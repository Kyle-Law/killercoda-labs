#!/bin/bash

echo -n "Installing Gateway API, Istio, three model servers..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done

if [ -f /tmp/.initbroken ]; then
  echo " FAILED"
  echo
  echo "These did not come up:$(cat /tmp/.initbroken)"
  echo "The install output is in /root/.init.log -- the last few lines usually say why."
else
  echo " done"
fi
echo
