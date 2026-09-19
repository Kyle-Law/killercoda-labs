#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · A backend that is not a Service"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

kubectl get gateway inference-gateway >/dev/null 2>&1 || fail \
  "There is no Gateway named 'inference-gateway'." \
  "" \
  "It needs gatewayClassName 'istio' and one HTTP listener on port 80. There is" \
  "no cloud load balancer here, so it also needs the annotation that makes Istio" \
  "expose it as a NodePort:" \
  "  annotations:" \
  "    networking.istio.io/service-type: NodePort" \
  "" \
  "Without that the Service waits forever for an address it will never get."

PROG=$(kubectl get gateway inference-gateway \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
[ "$PROG" == "True" ] || fail \
  "The Gateway exists but is not Programmed (Programmed=${PROG:-<none>})." \
  "" \
  "Istio creates the data plane from the Gateway object itself, which takes a" \
  "few seconds. If it stays this way, read the reason:" \
  "  kubectl get gateway inference-gateway -o jsonpath='{.status.conditions}' | tr ',' '\\n'" \
  "" \
  "'AddressNotAssigned' means the Service is still a LoadBalancer waiting for an" \
  "address. Add the networking.istio.io/service-type: NodePort annotation."

ROUTE=$(kubectl get httproute llm-route -o json 2>/dev/null)
[ -n "$ROUTE" ] || fail \
  "There is no HTTPRoute named 'llm-route'." \
  "" \
  "It attaches to the Gateway and sends everything to the InferencePool."

KIND=$(kubectl get httproute llm-route -o jsonpath='{.spec.rules[0].backendRefs[0].kind}' 2>/dev/null)
NAME=$(kubectl get httproute llm-route -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)
GROUP=$(kubectl get httproute llm-route -o jsonpath='{.spec.rules[0].backendRefs[0].group}' 2>/dev/null)
if [ "$KIND" != "InferencePool" ]; then
  fail \
    "The route's backend is a ${KIND:-Service} named '${NAME:-<none>}', not an InferencePool." \
    "" \
    "This is the distinctive part of the Inference Extension: the backend is not a" \
    "Service at all. A Service would load balance across the replicas itself, which" \
    "is exactly the behaviour being replaced." \
    "" \
    "  backendRefs:" \
    "  - group: inference.networking.k8s.io" \
    "    kind: InferencePool" \
    "    name: vllm-qwen3-32b" \
    "" \
    "  kubectl get inferencepool"
fi
[ "$GROUP" == "inference.networking.k8s.io" ] || fail \
  "The backendRef names kind InferencePool but group '${GROUP:-<empty>}'." \
  "" \
  "An empty group means the core API group, where InferencePool does not exist." \
  "It has to be spelled out:" \
  "  group: inference.networking.k8s.io"

for c in Accepted ResolvedRefs; do
  S=$(kubectl get httproute llm-route \
    -o jsonpath="{.status.parents[0].conditions[?(@.type==\"$c\")].status}" 2>/dev/null)
  [ "$S" == "True" ] || fail \
    "The route's $c condition is '${S:-<none>}', not True." \
    "" \
    "  kubectl get httproute llm-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\\n'" \
    "" \
    "ResolvedRefs failing usually means the InferencePool name is wrong or the" \
    "pool is in another namespace:" \
    "  kubectl get inferencepool"
done

PORT=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
[ -n "$PORT" ] || fail \
  "The Gateway's Service has no NodePort for port 80." \
  "" \
  "  kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway" \
  "" \
  "If its TYPE is LoadBalancer, add the annotation from the task and re-apply."

# The path has to carry a real request end to end, through the picker.
for _ in 1 2 3 4; do
  BODY=$(curl -s -m 20 "http://localhost:$PORT/v1/completions" \
    -H 'Content-Type: application/json' \
    -d '{"model":"Qwen/Qwen3-32B","prompt":"hello","max_tokens":20}' 2>/dev/null)
  echo "$BODY" | grep -q '"text_completion"' && pass
  sleep 5
done

EPP=$(kubectl get pod -l inferencepool=vllm-qwen3-32b-epp \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
fail \
  "Everything is wired up, but a request does not come back with a completion." \
  "" \
  "  what came back:  $(echo "$BODY" | head -c 220)" \
  "  endpoint picker: ${EPP:-<not found>}" \
  "" \
  "If the body is empty the gateway had nowhere to send the request -- the picker" \
  "is consulted per request and the route fails when it cannot be reached:" \
  "  kubectl get pod -l inferencepool=vllm-qwen3-32b-epp" \
  "  kubectl logs -l inferencepool=vllm-qwen3-32b-epp --tail=20" \
  "" \
  "Note the label is 'inferencepool=...-epp', not 'app='." \
  "" \
  "A 404 saying the model does not exist would be fine here, by the way -- that" \
  "error comes from the simulator, so it proves the whole path. This check asks" \
  "for a real completion, so use the model name from the task."
