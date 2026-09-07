#!/bin/bash

# the overlay must exist and actually apply a prefix
[ -f /root/app/prod/kustomization.yaml ] || exit 1
grep -qE '^namePrefix:[[:space:]]*prod-' /root/app/prod/kustomization.yaml || exit 1

# the prefixed objects must be in the cluster
kubectl get svc prod-backend >/dev/null 2>&1 || exit 1
kubectl get configmap prod-appcfg >/dev/null 2>&1 || exit 1
kubectl get deploy prod-frontend >/dev/null 2>&1 || exit 1

# and the breakage must be real: the ConfigMap still points at the OLD name,
# which is the whole point of the step
HOST=$(kubectl get configmap prod-appcfg -o jsonpath='{.data.BACKEND_HOST}' 2>/dev/null)
[ "$HOST" == "backend" ] || exit 1

# confirm it is actually failing at runtime, not just theoretically wrong
for i in $(seq 1 18); do
  kubectl logs -l app=frontend --tail=20 2>/dev/null | grep -q "FAIL cannot reach" && exit 0
  sleep 5
done

exit 1
