#!/bin/bash

# the base change must be committed
grep -q "periodSeconds: 17" /root/solar-kustomize/base/deployment.yaml 2>/dev/null || exit 1
cd /root/solar-kustomize 2>/dev/null || exit 1
git diff --quiet HEAD -- base/deployment.yaml || exit 1

# and it must have reached BOTH environments - that is the demonstration
for i in $(seq 1 30); do
  S=$(kubectl get deploy solar-system -n staging -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.periodSeconds}' 2>/dev/null)
  P=$(kubectl get deploy solar-system -n prod    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.periodSeconds}' 2>/dev/null)
  if [ "$S" == "17" ] && [ "$P" == "17" ]; then exit 0; fi
  sleep 5
done

exit 1
