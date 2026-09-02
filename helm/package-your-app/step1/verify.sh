#!/bin/bash

kubectl get configmap site >/dev/null 2>&1 || exit 1

# the task asks for a Deployment specifically - without this a bare Pod
# plus a Service would satisfy every other check here
kubectl get deployment site >/dev/null 2>&1 || exit 1

TYPE=$(kubectl get svc site -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$TYPE" == "NodePort" ] || exit 1

PORT=$(kubectl get svc site -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
[ "$PORT" == "30080" ] || exit 1

# the page must actually be served through the NodePort, not merely defined
for i in $(seq 1 18); do
  curl -s --max-time 5 http://localhost:30080 2>/dev/null | grep -q "Served by nginx" && exit 0
  sleep 5
done

exit 1
