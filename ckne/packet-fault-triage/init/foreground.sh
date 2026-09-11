#!/bin/bash

echo -n "Building three network namespaces and breaking one of them..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 1; done
echo " done"
echo
