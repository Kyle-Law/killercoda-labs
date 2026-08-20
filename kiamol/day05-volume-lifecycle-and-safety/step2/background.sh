#!/bin/bash

mkdir -p /var/log/app-a /var/log/app-b
echo "secret-a" > /var/log/app-a/marker.txt
echo "secret-b" > /var/log/app-b/marker.txt

touch /tmp/step2-applied
