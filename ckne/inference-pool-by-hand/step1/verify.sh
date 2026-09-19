#!/bin/bash
LOG=/root/.check
STEP="Step 1 · The two objects the chart would have written"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

POOL=$(kubectl get inferencepool llm-pool -o json 2>/dev/null)
[ -n "$POOL" ] || fail \
  "There is no InferencePool named 'llm-pool'." \
  "" \
  "The picker is already running and is looking for a pool by that name -- it" \
  "was started with --pool-name llm-pool. Until the pool exists it has nothing" \
  "to serve:" \
  "  kubectl get deploy llm-epp -o jsonpath='{.spec.template.spec.containers[0].args}'"

SEL=$(echo "$POOL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["spec"].get("selector",{}).get("matchLabels",{}).get("app",""))' 2>/dev/null)
[ "$SEL" == "vllm-qwen3-32b" ] || fail \
  "The pool's selector is '${SEL:-<none>}', which does not select the model servers." \
  "" \
  "A pool selects Pods by label, in its own namespace:" \
  "  kubectl get pods -l app=vllm-qwen3-32b --show-labels"

PORT=$(echo "$POOL" | python3 -c 'import json,sys; t=json.load(sys.stdin)["spec"].get("targetPorts",[{}]); print(t[0].get("number",""))' 2>/dev/null)
[ "$PORT" == "8000" ] || fail \
  "The pool's targetPorts names port ${PORT:-<none>}, not 8000." \
  "" \
  "This is the port on the model server Pods themselves, not a Service port --" \
  "there is no Service in this path at all:" \
  "  kubectl get pod -l app=vllm-qwen3-32b -o jsonpath='{.items[0].spec.containers[0].ports}'"

EPPNAME=$(echo "$POOL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["spec"].get("endpointPickerRef",{}).get("name",""))' 2>/dev/null)
EPPPORT=$(echo "$POOL" | python3 -c 'import json,sys; print(json.load(sys.stdin)["spec"].get("endpointPickerRef",{}).get("port",{}).get("number",""))' 2>/dev/null)
[ "$EPPNAME" == "llm-epp" ] || fail \
  "The pool's endpointPickerRef names '${EPPNAME:-<nothing>}'." \
  "" \
  "It has to name the picker's Service. The kind defaults to Service, so only" \
  "the name and port are required:" \
  "  kubectl get svc llm-epp"
[ "$EPPPORT" == "9002" ] || fail \
  "The endpointPickerRef port is ${EPPPORT:-<unset>}, not 9002." \
  "" \
  "9002 is the picker's ext_proc port -- the one the gateway calls per request." \
  "9003 is its health port and 9090 is metrics; neither will work here:" \
  "  kubectl get svc llm-epp -o jsonpath='{.spec.ports}'"

kubectl get httproute llm-route >/dev/null 2>&1 || fail \
  "There is no HTTPRoute named 'llm-route'." \
  "" \
  "The Gateway already exists. The route attaches to it and sends traffic to" \
  "the pool:" \
  "  kubectl get gateway inference-gateway"

KIND=$(kubectl get httproute llm-route -o jsonpath='{.spec.rules[0].backendRefs[0].kind}' 2>/dev/null)
GROUP=$(kubectl get httproute llm-route -o jsonpath='{.spec.rules[0].backendRefs[0].group}' 2>/dev/null)
[ "$KIND" == "InferencePool" ] && [ "$GROUP" == "inference.networking.k8s.io" ] || fail \
  "The route's backendRef is kind '${KIND:-Service}' in group '${GROUP:-<core>}'." \
  "" \
  "Both have to be spelled out -- a backendRef defaults to a Service in the core" \
  "group, and neither default is right here:" \
  "  backendRefs:" \
  "  - group: inference.networking.k8s.io" \
  "    kind: InferencePool" \
  "    name: llm-pool"

for c in Accepted ResolvedRefs; do
  S=$(kubectl get httproute llm-route -o jsonpath="{.status.parents[0].conditions[?(@.type==\"$c\")].status}" 2>/dev/null)
  [ "$S" == "True" ] || fail \
    "The route's $c condition is '${S:-<none>}'." \
    "" \
    "  kubectl get httproute llm-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\\n'"
done

P=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
[ -n "$P" ] || fail "The Gateway has no NodePort." "" "  kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway"

for _ in 1 2 3 4; do
  B=$(curl -s -m 25 "http://localhost:$P/v1/completions" -H 'Content-Type: application/json' \
      -d '{"model":"Qwen/Qwen3-32B","prompt":"hello","max_tokens":20}' 2>/dev/null)
  echo "$B" | grep -q '"text_completion"' && pass
  sleep 5
done

fail \
  "Everything is declared correctly, but a request does not come back with a completion." \
  "" \
  "  what came back: $(echo "$B" | head -c 200)" \
  "" \
  "Check the picker is Ready and has no complaints of its own:" \
  "  pickerlog" \
  "" \
  "It can take a few seconds after the pool appears for the gateway to program" \
  "the route -- try CHECK again before going further."
