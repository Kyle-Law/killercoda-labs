#!/bin/bash

echo -n "Taking this cluster's pod network away..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
