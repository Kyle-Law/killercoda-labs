#!/bin/bash

[ -s /root/templates ] || exit 1

for t in configmap.yaml deployment.yaml hpa.yaml service.yaml; do
  grep -q "$t" /root/templates || exit 1
done

exit 0
