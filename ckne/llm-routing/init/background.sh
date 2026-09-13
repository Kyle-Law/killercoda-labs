#!/bin/bash

SIM_IMAGE=ghcr.io/llm-d/llm-d-inference-sim:v0.11.2
EG_VERSION=v1.2.6

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash /tmp/get_helm.sh >/dev/null 2>&1
fi

for IMG in "$SIM_IMAGE" registry.k8s.io/e2e-test-images/agnhost:2.53 "docker.io/envoyproxy/gateway:${EG_VERSION}"; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 || crictl pull "$IMG" >/dev/null 2>&1 || true
done

# Envoy Gateway ships its own copy of the Gateway API CRDs; installing them
# separately first causes a field-manager conflict, so the chart owns them.
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "$EG_VERSION" \
  --namespace envoy-gateway-system --create-namespace \
  --wait --timeout 6m >/dev/null 2>&1

cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
# Two replicas of the same "model", deliberately unequal. A real fleet gets
# this way on its own: different GPU types, a node under memory pressure, one
# replica still warming its KV cache.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chat-fast
spec:
  replicas: 1
  selector:
    matchLabels: {app: chat, speed: fast}
  template:
    metadata:
      labels: {app: chat, speed: fast}
    spec:
      containers:
      - name: sim
        image: ${SIM_IMAGE}
        imagePullPolicy: IfNotPresent
        args: ["--port=8000","--model=demo-model","--served-model-name=demo-model","--mode=echo","--time-to-first-token=200ms","--inter-token-latency=10ms","--max-num-seqs=8"]
        ports: [{containerPort: 8000}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chat-slow
spec:
  replicas: 1
  selector:
    matchLabels: {app: chat, speed: slow}
  template:
    metadata:
      labels: {app: chat, speed: slow}
    spec:
      containers:
      - name: sim
        image: ${SIM_IMAGE}
        imagePullPolicy: IfNotPresent
        args: ["--port=8000","--model=demo-model","--served-model-name=demo-model","--mode=echo","--time-to-first-token=1s","--inter-token-latency=400ms","--max-num-seqs=1","--max-waiting-queue-length=1000"]
        ports: [{containerPort: 8000}]
---
apiVersion: v1
kind: Service
metadata:
  name: chat
spec:
  selector: {app: chat}
  ports: [{port: 80, targetPort: 8000}]
---
apiVersion: v1
kind: Service
metadata:
  name: chat-slow
spec:
  selector: {app: chat, speed: slow}
  ports: [{port: 80, targetPort: 8000}]
---
# A second, completely different model served by its own Deployment.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: embed
spec:
  replicas: 1
  selector:
    matchLabels: {app: embed}
  template:
    metadata:
      labels: {app: embed}
    spec:
      containers:
      - name: sim
        image: ${SIM_IMAGE}
        imagePullPolicy: IfNotPresent
        args: ["--port=8000","--model=tiny-embed","--served-model-name=tiny-embed","--mode=random","--time-to-first-token=50ms","--inter-token-latency=5ms","--max-num-seqs=8"]
        ports: [{containerPort: 8000}]
---
apiVersion: v1
kind: Service
metadata:
  name: embed
spec:
  selector: {app: embed}
  ports: [{port: 80, targetPort: 8000}]
---
apiVersion: v1
kind: Pod
metadata:
  name: cli
  labels: {app: cli}
spec:
  containers:
  - name: cli
    image: registry.k8s.io/e2e-test-images/agnhost:2.53
    command: ["/bin/sh","-c","sleep infinity"]
EOF

kubectl rollout status deployment/chat-fast --timeout=300s >/dev/null 2>&1
kubectl rollout status deployment/chat-slow --timeout=300s >/dev/null 2>&1
kubectl rollout status deployment/embed --timeout=300s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod/cli --timeout=300s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The Gateway's address. Envoy Gateway names the Service after the Gateway with
# a hash suffix, so look it up by label rather than hardcoding a name.
cat > /usr/local/bin/gwaddr <<'WRAP'
#!/bin/bash
kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name="${1:-llm-gateway}" \
  -o jsonpath='{.items[0].spec.clusterIP}'
WRAP
chmod +x /usr/local/bin/gwaddr

# Open-loop load: one request launched every INTERVAL seconds, COUNT times,
# without waiting for the previous one. Real inference traffic arrives this
# way -- users do not wait for each other -- and it is the only shape under
# which a slow replica is allowed to fall behind.
cat > /usr/local/bin/llmload <<'WRAP'
#!/bin/bash
INTERVAL=${1:-0.4}
COUNT=${2:-50}
WORDS=${3:-20}
GW=$(gwaddr)
# echo mode returns the prompt back, so a fixed-length prompt makes every
# request cost exactly the same number of tokens on a given replica.
PROMPT=$(awk -v n="$WORDS" 'BEGIN{for(i=1;i<=n;i++) printf "word%d ", i}')
[ -z "$GW" ] && { echo "no gateway address yet"; exit 1; }

kubectl exec cli -- /bin/sh -c "
rm -f /tmp/lat.txt
for i in \$(seq 1 $COUNT); do
  ( curl -s -m 40 -o /dev/null -w '%{time_total} %{http_code}\n' \
      -X POST 'http://$GW/v1/chat/completions' -H 'Content-Type: application/json' \
      -d '{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":200}' \
      >> /tmp/lat.txt ) &
  sleep $INTERVAL
done
wait
TOTAL=\$(wc -l < /tmp/lat.txt)
echo \"  requests:  \$TOTAL\"
echo \"  failed:    \$(grep -vc ' 200' /tmp/lat.txt)\"
echo \"  median:    \$(sort -n /tmp/lat.txt | awk -v t=\$TOTAL 'NR==int(t*0.5){print \$1}')s\"
echo \"  p90:       \$(sort -n /tmp/lat.txt | awk -v t=\$TOTAL 'NR==int(t*0.9){print \$1}')s\"
echo \"  slowest:   \$(sort -rn /tmp/lat.txt | head -1 | cut -d' ' -f1)s\"
"
WRAP
chmod +x /usr/local/bin/llmload

# Per-replica truth: what the model server says about its own queue, next to
# what the container runtime says about its CPU. These two numbers disagreeing
# is the entire point of step 4.
cat > /usr/local/bin/llmstats <<'WRAP'
#!/bin/bash
printf "%-32s %11s %9s %9s\n" POD CPU_mCORES RUNNING WAITING
kubectl get pods -l 'app in (chat,embed)' \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.podIP}{"\n"}{end}' 2>/dev/null \
| while read -r POD IP; do
    [ -z "$IP" ] && continue
    # crictl's table puts POD in the second-to-last column, which is stable
    # even though CREATED ("46 seconds ago") is several words wide.
    CID=$(crictl ps --name sim 2>/dev/null | awk -v p="$POD" 'NR>1 && $(NF-1)==p {print $1}')
    MC="?"
    if [ -n "$CID" ]; then
      NANO=$(crictl stats -o json --id "$CID" 2>/dev/null \
        | grep -A1 usageNanoCores | grep '"value"' | head -1 | cut -d'"' -f4)
      [ -n "$NANO" ] && MC=$(( NANO / 1000000 ))
    fi
    M=$(kubectl exec cli -- curl -s -m 3 "http://$IP:8000/metrics" 2>/dev/null)
    RUN=$(echo "$M" | awk '/^vllm:num_requests_running/{print $2}')
    WAIT=$(echo "$M" | awk '/^vllm:num_requests_waiting/{print $2}')
    printf "%-32s %11s %9s %9s\n" "$POD" "$MC" "${RUN:-?}" "${WAIT:-?}"
  done
WRAP
chmod +x /usr/local/bin/llmstats

touch /tmp/.initfinished
