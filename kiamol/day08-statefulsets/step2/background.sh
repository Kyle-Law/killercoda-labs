#!/bin/bash

kubectl run dns-client --image=busybox:1.28 --command -- sleep 3600

touch /tmp/step2-applied
