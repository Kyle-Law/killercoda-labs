#!/bin/bash

# RBAC changes don't flap once correct, but can take a moment to propagate -
# retry rather than requiring sustained success
for i in $(seq 1 4); do
  kubectl auth can-i list pods --as=system:serviceaccount:default:viewer-sa 2>/dev/null | grep -q "^yes$" && exit 0
  sleep 2
done

exit 1
