#!/bin/bash

GWAPI_VERSION=v1.5.1
GAIE_VERSION=v1.5.0
ISTIO_VERSION=1.30.4   # the Helm chart index lags the GitHub releases
SIM_IMAGE=ghcr.io/llm-d/llm-d-inference-sim:v0.8.2
EPP_IMAGE=registry.k8s.io/gateway-api-inference-extension/epp:${GAIE_VERSION}

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash /tmp/get_helm.sh >/dev/null 2>&1
fi

# The EPP image is large and comes from registry.k8s.io; pulling it lazily has
# been measured at several minutes, which is long enough to time out the first
# check. Pull everything up front instead.
for IMG in "$SIM_IMAGE" "$EPP_IMAGE" \
           "docker.io/istio/pilot:${ISTIO_VERSION}" \
           "docker.io/istio/proxyv2:${ISTIO_VERSION}"; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 || crictl pull "$IMG" >/dev/null 2>&1 || true
done

# Gateway API first, then the Inference Extension's own CRDs. Server-side apply
# because the Gateway API CRDs are large enough to exceed the annotation limit.
kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GWAPI_VERSION}/standard-install.yaml" >/dev/null 2>&1
kubectl apply -f \
  "https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/${GAIE_VERSION}/manifests.yaml" >/dev/null 2>&1

# Istio as a gateway only -- no sidecar injection anywhere, which is what keeps
# it clear of Cilium's socket load balancing. istiod asks for 2Gi by default.
helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null 2>&1
helm repo update >/dev/null 2>&1
helm install istio-base istio/base --version "$ISTIO_VERSION" \
  -n istio-system --create-namespace --set defaultRevision=default \
  --wait --timeout 5m >>/root/.init.log 2>&1
helm install istiod istio/istiod --version "$ISTIO_VERSION" -n istio-system \
  --set pilot.env.SUPPORT_GATEWAY_API_INFERENCE_EXTENSION=true \
  --set pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true \
  --set pilot.resources.requests.cpu=100m \
  --set pilot.resources.requests.memory=256Mi \
  --wait --timeout 8m >>/root/.init.log 2>&1

# Three replicas of the simulator, serving one base model and one fake LoRA.
kubectl apply -f \
  "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api-inference-extension/refs/tags/${GAIE_VERSION}/config/manifests/vllm/sim-deployment.yaml" >/dev/null 2>&1
kubectl rollout status deploy/vllm-qwen3-32b --timeout=300s >/dev/null 2>&1

# The InferencePool and its Endpoint Picker come from one chart at this version.
# The chart's default EPP memory limit is 16Gi, which will not schedule here.
#
# 500m rather than something smaller: the EPP's readiness probe is a gRPC check
# with a 1s timeout, and at 100m it loses that race while scoring a burst of
# concurrent requests. The Pod then flaps NotReady, the gateway drops it from
# the ext_proc cluster, and every request in flight returns 500 -- intermittently,
# and only under load, which is the worst way for a lab to fail.
helm install vllm-qwen3-32b \
  --dependency-update \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  --set provider.name=istio \
  --set inferenceExtension.resources.requests.cpu=500m \
  --set inferenceExtension.resources.requests.memory=256Mi \
  --set inferenceExtension.resources.limits.memory=1Gi \
  --version "$GAIE_VERSION" \
  oci://registry.k8s.io/gateway-api-inference-extension/charts/inferencepool >>/root/.init.log 2>&1
kubectl rollout status deploy/vllm-qwen3-32b-epp --timeout=300s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

mkdir -p /root/answers

# Killercoda shows only pass/fail, never a verify script's output, so each
# check writes its reason to /root/.check and `why` prints it.
cat > /usr/local/bin/why <<'WRAP'
#!/bin/bash
if [ -s /root/.check ]; then
  cat /root/.check
else
  echo "No check has run yet -- press CHECK, then run 'why' again."
fi
WRAP
chmod +x /usr/local/bin/why

# Per-replica request counters, read through the API server's pod proxy so
# nothing has to be port-forwarded or deployed.
cat > /usr/local/bin/igcount <<'WRAP'
#!/bin/bash
for p in $(kubectl get pod -l app=vllm-qwen3-32b -o jsonpath='{.items[*].metadata.name}'); do
  n=$(kubectl get --raw "/api/v1/namespaces/default/pods/$p:8000/proxy/metrics" 2>/dev/null \
      | grep -E '^vllm:request_success_total' | awk '{s+=$2} END {print s+0}')
  printf "%-36s %s\n" "$p" "${n:-0}"
done
WRAP
chmod +x /usr/local/bin/igcount

# Live view: what each replica is working on and what is waiting behind it.
cat > /usr/local/bin/igqueue <<'WRAP'
#!/bin/bash
printf "%-36s %9s %9s %8s\n" POD RUNNING WAITING KV
for p in $(kubectl get pod -l app=vllm-qwen3-32b -o jsonpath='{.items[*].metadata.name}'); do
  m=$(kubectl get --raw "/api/v1/namespaces/default/pods/$p:8000/proxy/metrics" 2>/dev/null)
  r=$(echo "$m" | grep '^vllm:num_requests_running'  | awk '{print $2}')
  w=$(echo "$m" | grep '^vllm:num_requests_waiting'  | awk '{print $2}')
  k=$(echo "$m" | grep -E '^vllm:(kv|gpu)_cache_usage_perc' | awk '{print $2}')
  printf "%-36s %9s %9s %8s\n" "$p" "${r:-?}" "${w:-?}" "${k:-?}"
done
WRAP
chmod +x /usr/local/bin/igqueue

# Load generator. Snapshots the per-replica counters either side of the run and
# prints the DELTA, because the counters are cumulative and every EPP or
# simulator restart resets the picker's prefix tracking -- comparing totals
# across a restart is the classic way to misread this lab.
cat > /usr/local/bin/igload <<'WRAP'
#!/bin/bash
# usage: igload <count> [same|diff|long] [parallelism]
N=${1:-60}; MODE=${2:-diff}; PAR=${3:-10}

PORT=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
        -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
[ -z "$PORT" ] && { echo "No NodePort for a Gateway named 'inference-gateway' yet."; exit 1; }
URL="http://localhost:$PORT/v1/completions"

snap() {
  for p in $(kubectl get pod -l app=vllm-qwen3-32b -o jsonpath='{.items[*].metadata.name}'); do
    n=$(kubectl get --raw "/api/v1/namespaces/default/pods/$p:8000/proxy/metrics" 2>/dev/null \
        | grep -E '^vllm:request_success_total' | awk '{s+=$2} END {print s+0}')
    echo "$p ${n:-0}"
  done
}

BEFORE=$(snap)
SYS=$(for i in $(seq 1 30); do printf "You are a helpful restaurant assistant. Rule %s: be polite. " "$i"; done)
export URL MODE SYS
CODES=$(seq 1 "$N" | xargs -P "$PAR" -I{} bash -c '
  case "$MODE" in
    same) P="hello" ;;
    diff) P="hello {} $(date +%N)" ;;
    long) P="$SYS Question {}: what is good today?" ;;
  esac
  curl -s -o /dev/null -m 60 -w "%{http_code}\n" "$URL" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"Qwen/Qwen3-32B\",\"prompt\":\"$P\",\"max_tokens\":20}"' | sort | uniq -c)
AFTER=$(snap)

echo "  status codes:"
echo "$CODES" | sed 's/^/   /'
echo "  requests served, this run only:"
echo "$BEFORE" | while read -r pod before; do
  after=$(echo "$AFTER" | awk -v p="$pod" '$1==p {print $2}')
  printf "   %-36s %s\n" "$pod" "$(( ${after:-0} - before ))"
done
WRAP
chmod +x /usr/local/bin/igload

# Say so rather than reporting success over a broken cluster: a lab that starts
# with a missing GatewayClass wastes the learner's time on a fault that is not
# theirs. The detail is in /root/.init.log.
MISSING=""
kubectl get gatewayclass istio >/dev/null 2>&1 || MISSING="$MISSING GatewayClass/istio"
kubectl get inferencepool vllm-qwen3-32b >/dev/null 2>&1 || MISSING="$MISSING InferencePool/vllm-qwen3-32b"
kubectl get deploy vllm-qwen3-32b-epp >/dev/null 2>&1 || MISSING="$MISSING Deployment/vllm-qwen3-32b-epp"
[ -n "$MISSING" ] && echo "$MISSING" > /tmp/.initbroken

touch /tmp/.initfinished
