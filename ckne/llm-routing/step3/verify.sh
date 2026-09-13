#!/bin/bash

GW=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=llm-gateway \
  -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
[ -n "$GW" ] || exit 1

# A header match routing to the embed backend must exist.
kubectl get httproute chat-route -o json 2>/dev/null | grep -q '"embed"' || exit 1
kubectl get httproute chat-route -o json 2>/dev/null | grep -qi 'x-model' || exit 1

for _ in $(seq 1 6); do
  WITH=$(kubectl exec cli -- curl -s -m 30 -X POST "http://$GW/v1/chat/completions" \
    -H 'Content-Type: application/json' -H 'x-model: tiny-embed' \
    -d '{"model":"tiny-embed","messages":[{"role":"user","content":"hello"}],"max_tokens":40}' 2>/dev/null)

  # Routed correctly: a real completion from the tiny-embed server, not a 404.
  if echo "$WITH" | grep -q '"model":"tiny-embed"' && ! echo "$WITH" | grep -q 'does not exist'; then
    # ...and the default route must still serve demo-model traffic.
    DEF=$(kubectl exec cli -- curl -s -m 30 -X POST "http://$GW/v1/chat/completions" \
      -H 'Content-Type: application/json' \
      -d '{"model":"demo-model","messages":[{"role":"user","content":"hi"}],"max_tokens":20}' 2>/dev/null)
    echo "$DEF" | grep -q '"model":"demo-model"' && exit 0
  fi
  sleep 5
done

exit 1
