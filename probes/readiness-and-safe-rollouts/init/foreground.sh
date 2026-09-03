#!/bin/bash

echo -n "Deploying shop v1 across 4 replicas..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
