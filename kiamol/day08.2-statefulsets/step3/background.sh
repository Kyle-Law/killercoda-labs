#!/bin/bash

kubectl scale statefulset db --replicas=3

touch /tmp/step3-applied
