#!/bin/bash

TARGET="Hello Killercoda Folks! You received this message: You successfully automated the rollout!"

# the checksum annotation must actually be present on the Pod template -
# without it, a manual 'kubectl rollout restart' could produce the right
# message without demonstrating the mechanism this scenario teaches
# fetch the whole annotations map rather than a jsonpath keyed on
# "checksum/config" - the '/' would need escaping and this avoids the question
kubectl get deployment mock-app-deployment -n dev-ns \
  -o jsonpath='{.spec.template.metadata.annotations}' 2>/dev/null \
  | grep -q "checksum/config" || exit 1

SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$SERVICE_IP" ] || exit 1

for i in $(seq 1 18); do
  ACTUAL=$(curl -s --max-time 5 "http://${SERVICE_IP}:5000" 2>/dev/null)
  [ "$ACTUAL" == "$TARGET" ] && exit 0
  sleep 5
done

exit 1
