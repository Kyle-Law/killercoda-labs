#!/bin/bash

# the per-environment values file is the point of the step - passing the same
# three overrides as --set flags would defeat it
[ -f /root/charts/site/values-prod.yaml ] || exit 1
grep -q "prod" /root/charts/site/values-prod.yaml || exit 1

# both releases must exist, from the same chart
helm status dev >/dev/null 2>&1 || exit 1
helm status prod >/dev/null 2>&1 || exit 1

# prod runs 2 replicas, dev still runs 1 - proves the override applied to
# prod only and that values.yaml was not edited instead
PROD_SPEC=$(kubectl get deployment prod-site -o jsonpath='{.spec.replicas}' 2>/dev/null)
DEV_SPEC=$(kubectl get deployment dev-site -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "$PROD_SPEC" == "2" ] || exit 1
[ "$DEV_SPEC" == "1" ] || exit 1

PROD_PORT=$(kubectl get svc prod-site -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
[ "$PROD_PORT" == "30081" ] || exit 1

# both must serve their own environment at the same time
for i in $(seq 1 18); do
  DEV_PAGE=$(curl -s --max-time 5 http://localhost:30080 2>/dev/null)
  PROD_PAGE=$(curl -s --max-time 5 http://localhost:30081 2>/dev/null)
  if echo "$DEV_PAGE" | grep -q "Hello from dev" && echo "$PROD_PAGE" | grep -q "Hello from prod"; then
    exit 0
  fi
  sleep 5
done

exit 1
