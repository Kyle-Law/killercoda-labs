#!/bin/bash

for i in $(seq 1 6); do
  helm status podinfo2 2>/dev/null | grep -q "^STATUS: failed" && exit 0
  sleep 10
done

exit 1
