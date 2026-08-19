#!/bin/bash

for i in $(seq 1 4); do
  kubectl auth can-i list nodes --as=system:serviceaccount:default:node-viewer-sa 2>/dev/null | grep -q "^yes$" && exit 0
  sleep 2
done

exit 1
