#!/bin/bash

TARGET="You are overriding the message. Does the pod take this change in consideration?"

for i in $(seq 1 12); do
  ACTUAL=$(kubectl get cm -n dev-ns mock-app-configmap -o jsonpath='{.data.MESSAGE}' 2>/dev/null)
  [ "$ACTUAL" == "$TARGET" ] && exit 0
  sleep 5
done

exit 1
