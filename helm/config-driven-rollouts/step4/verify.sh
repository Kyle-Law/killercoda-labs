#!/bin/bash

TARGET="Hello Killercoda Folks! You received this message: You are overriding the message. Does the pod take this change in consideration?"

SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$SERVICE_IP" ] || exit 1

for i in $(seq 1 18); do
  ACTUAL=$(curl -s --max-time 5 "http://${SERVICE_IP}:5000" 2>/dev/null)
  [ "$ACTUAL" == "$TARGET" ] && exit 0
  sleep 5
done

exit 1
