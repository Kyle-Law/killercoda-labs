#!/bin/bash

# replacements must be doing the work, not vars
grep -q "^replacements:" /root/app/prod/kustomization.yaml 2>/dev/null || exit 1
if grep -q "^vars:" /root/app/prod/kustomization.yaml 2>/dev/null; then exit 1; fi

# the rendered ConfigMap must carry the PREFIXED service name - proving the
# replacement resolved rather than leaving a placeholder
RENDER=$(kubectl kustomize /root/app/prod 2>/dev/null)
echo "$RENDER" | grep -qE 'BACKEND_HOST: "?prod-backend"?' || exit 1

# and it must be live in the cluster
HOST=$(kubectl get configmap prod-appcfg -o jsonpath='{.data.BACKEND_HOST}' 2>/dev/null)
[ "$HOST" == "prod-backend" ] || exit 1

# finally the app must actually recover - the whole point
for i in $(seq 1 24); do
  RECENT=$(kubectl logs -l app=frontend --tail=5 2>/dev/null)
  if echo "$RECENT" | grep -q "OK reached prod-backend"; then exit 0; fi
  sleep 5
done

exit 1
