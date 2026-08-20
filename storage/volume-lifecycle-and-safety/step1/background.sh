#!/bin/bash

kubectl run data-pod --image=busybox --command -- sh -c "sleep 3600"

touch /tmp/step1-applied
