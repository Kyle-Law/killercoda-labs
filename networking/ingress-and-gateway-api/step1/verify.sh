#!/bin/bash

for i in $(seq 1 8); do
  kubectl exec curl-test -- wget -qO- --header="Host: web.example.com" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local 2>/dev/null \
    | grep -qi "Welcome to nginx" && exit 0
  sleep 10
done

exit 1
