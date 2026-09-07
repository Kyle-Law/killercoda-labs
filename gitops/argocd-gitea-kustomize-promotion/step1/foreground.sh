#!/bin/bash

echo "Installing Argo CD and Gitea — this takes a couple of minutes..."
while [ ! -f /tmp/step1-applied ]; do echo -n '.'; sleep 2; done
echo " done"
echo
