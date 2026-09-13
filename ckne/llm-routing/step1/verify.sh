#!/bin/bash

kubectl get gateway llm-gateway >/dev/null 2>&1 || exit 1

# The route must carry an explicit timeout setting -- the default is what
# truncated the stream, so leaving it unset cannot be a pass.
TO=$(kubectl get httproute chat-route -o jsonpath='{.spec.rules[0].timeouts.request}' 2>/dev/null)
[ -n "$TO" ] || exit 1

GW=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=llm-gateway \
  -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
[ -n "$GW" ] || exit 1

PROMPT=$(awk 'BEGIN{for(i=1;i<=50;i++) printf "word%d ", i}')

for _ in $(seq 1 3); do
  kubectl exec cli -- curl -s -N -m 150 -o /tmp/verify1.txt \
    -X POST "http://$GW/v1/chat/completions" -H 'Content-Type: application/json' \
    -d "{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":200,\"stream\":true}" \
    >/dev/null 2>&1

  # A complete SSE stream ends with the [DONE] sentinel. That -- not the
  # status code, which was 200 even when truncated -- is the real check.
  kubectl exec cli -- grep -q 'DONE' /tmp/verify1.txt 2>/dev/null && exit 0
  sleep 5
done

exit 1
