#!/bin/bash

kubectl get pod config-pod -o yaml | grep -q "configMap:" || exit 1

kubectl exec config-pod -- cat /etc/config/app.properties | grep -q "color=blue"
