#!/bin/bash

kubectl get configmap sim-config >/dev/null 2>&1 || exit 1

# the Deployment must actually consume the ConfigMap, not just have it sitting
# alongside - otherwise the flags would still be inline
kubectl get deployment sim -o yaml 2>/dev/null | grep -q "sim-config" || exit 1

# echo mode is the observable proof the config took effect: a unique phrase
# sent in must come back out, which never happens in random mode
MARKER="echo-check-$$"
for i in $(seq 1 24); do
  RESP=$(curl -s --max-time 10 http://localhost:30800/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"dummy-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$MARKER\"}]}" 2>/dev/null)
  echo "$RESP" | grep -q "$MARKER" && exit 0
  sleep 5
done

exit 1
