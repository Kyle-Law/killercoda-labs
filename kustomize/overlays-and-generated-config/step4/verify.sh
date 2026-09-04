#!/bin/bash

# The hash must have been switched off deliberately...
grep -q "disableNameSuffixHash: *true" /root/app/base/kustomization.yaml 2>/dev/null || exit 1

# ...which means the live ConfigMap carries no hash suffix.
kubectl get configmap dev-shop-config >/dev/null 2>&1 || exit 1

CM_VALUE=$(kubectl get configmap dev-shop-config -o jsonpath='{.data.ui-message}' 2>/dev/null)
[ -n "$CM_VALUE" ] || exit 1

# The stored config must have moved on from what the base originally had.
echo "$CM_VALUE" | grep -q "greetings from the base" && exit 1

# The point of the step: what the app serves must NOT match what the
# ConfigMap now says -- the Pods were never restarted, so they are stale.
for i in $(seq 1 12); do
  SERVED=$(kubectl exec "$(kubectl get pods --field-selector=status.phase=Running -o name 2>/dev/null | grep '^pod/dev-shop-' | head -1)" -- wget -qO- localhost:9898/ 2>/dev/null \
    | grep -o '"message": "[^"]*"' | sed 's/.*: "//; s/"$//')
  if [ -n "$SERVED" ]; then
    if [ "$SERVED" != "$CM_VALUE" ]; then
      exit 0
    fi
    # Matching means a rollout happened after all -- the demonstration of
    # staleness hasn't been produced.
    exit 1
  fi
  sleep 5
done

exit 1
