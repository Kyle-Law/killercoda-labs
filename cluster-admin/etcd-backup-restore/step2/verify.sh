#!/bin/bash

# give the control plane time to come back up after the manifest swap
for i in $(seq 1 24); do
  HAS_IMPORTANT=0
  HAS_JUNK=0
  kubectl get configmap important-data >/dev/null 2>&1 && HAS_IMPORTANT=1
  kubectl get configmap post-snapshot-junk >/dev/null 2>&1 && HAS_JUNK=1

  if [ "$HAS_IMPORTANT" == "1" ] && [ "$HAS_JUNK" == "0" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
