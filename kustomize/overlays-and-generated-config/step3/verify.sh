#!/bin/bash

# The generator must live in the base, so every overlay inherits it.
grep -q "configMapGenerator" /root/app/base/kustomization.yaml 2>/dev/null || exit 1

# The container must consume it by reference, not by a hand-written name.
grep -q "configMapKeyRef" /root/app/base/deployment.yaml 2>/dev/null || exit 1
grep -q "PODINFO_UI_MESSAGE" /root/app/base/deployment.yaml 2>/dev/null || exit 1

# The rendered ConfigMap name must carry a generated hash suffix, and the
# Deployment's reference must have been rewritten to that same name.
RENDERED=$(kubectl kustomize /root/app/overlays/dev 2>/dev/null)
CM_NAME=$(echo "$RENDERED" | grep -A3 "^kind: ConfigMap" | grep "name:" | head -1 | awk '{print $2}')
[ -n "$CM_NAME" ] || exit 1
echo "$CM_NAME" | grep -Eq "^dev-shop-config-[a-z0-9]+$" || exit 1
echo "$RENDERED" | grep -q "name: $CM_NAME" || exit 1

# And it must be live, with the app actually serving the generated value.
for i in $(seq 1 30); do
  kubectl get configmap "$CM_NAME" >/dev/null 2>&1 && \
  kubectl get deployment dev-shop -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}' 2>/dev/null \
    | grep -q "$CM_NAME" && {
      MSG=$(kubectl exec "$(kubectl get pods --field-selector=status.phase=Running -o name 2>/dev/null | grep '^pod/dev-shop-' | head -1)" -- wget -qO- localhost:9898/ 2>/dev/null | grep -o '"message": "[^"]*"')
      echo "$MSG" | grep -q "greetings from the base" && exit 0
    }
  sleep 5
done

exit 1
