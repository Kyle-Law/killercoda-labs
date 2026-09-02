#!/bin/bash

kubectl get deployment sim >/dev/null 2>&1 || exit 1

TYPE=$(kubectl get svc sim -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$TYPE" == "NodePort" ] || exit 1
PORT=$(kubectl get svc sim -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
[ "$PORT" == "30800" ] || exit 1

# the saved model list must have come from the running simulator
[ -s /root/models.json ] || exit 1
grep -q "dummy-model" /root/models.json || exit 1

# and it must actually serve an OpenAI chat completion, not merely be up
for i in $(seq 1 24); do
  RESP=$(curl -s --max-time 5 http://localhost:30800/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"dummy-model","messages":[{"role":"user","content":"verify"}]}' 2>/dev/null)
  echo "$RESP" | grep -q '"choices"' && exit 0
  sleep 5
done

exit 1
