#!/bin/bash

SIM_IMAGE=ghcr.io/llm-d/llm-d-inference-sim:v0.11.2
CLI_IMAGE=curlimages/curl:8.11.1
PROM_IMAGE=prom/prometheus:v3.1.0
ADAPTER_CHART_VERSION=5.4.0
METRICS_SERVER_VERSION=v0.8.0

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

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash /tmp/get_helm.sh >/dev/null 2>&1
fi

# The cluster can still be coming up when this runs.
for _ in $(seq 1 60); do
  kubectl get nodes >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null 2>&1

for img in $SIM_IMAGE $CLI_IMAGE $PROM_IMAGE; do
  crictl pull $img >/dev/null 2>&1 || ctr -n k8s.io images pull $img >/dev/null 2>&1 || true
done

# metrics-server, for the CPU-based HPA in step 1. The kubelet's serving
# certificate is self-signed on a kubeadm node, hence --kubelet-insecure-tls.
if ! kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1; then
  kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml" >/dev/null 2>&1
  kubectl -n kube-system patch deploy metrics-server --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1
fi

kubectl create namespace serve >/dev/null 2>&1
kubectl create namespace monitoring >/dev/null 2>&1
kubectl config set-context --current --namespace=serve >/dev/null 2>&1

# A plain Prometheus that finds Pods by annotation. The namespace and pod
# labels are what prometheus-adapter uses to tie a series to a Pod.
cat <<YAML | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: ServiceAccount
metadata: {name: prometheus, namespace: monitoring}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: prometheus-pods}
rules:
- {apiGroups: [""], resources: [pods], verbs: [get, list, watch]}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: prometheus-pods}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: prometheus-pods}
subjects: [{kind: ServiceAccount, name: prometheus, namespace: monitoring}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: prometheus, namespace: monitoring}
data:
  prometheus.yml: |
    global: {scrape_interval: 5s}
    scrape_configs:
    - job_name: pods
      kubernetes_sd_configs: [{role: pod}]
      relabel_configs:
      - {source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape], action: keep, regex: "true"}
      - {source_labels: [__meta_kubernetes_pod_ip], target_label: __address__, replacement: "\$1:8000"}
      - {source_labels: [__meta_kubernetes_namespace], target_label: namespace}
      - {source_labels: [__meta_kubernetes_pod_name], target_label: pod}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: prometheus, namespace: monitoring}
spec:
  selector: {matchLabels: {app: prometheus}}
  template:
    metadata: {labels: {app: prometheus}}
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: $PROM_IMAGE
        args: ["--config.file=/etc/prometheus/prometheus.yml"]
        ports: [{containerPort: 9090}]
        volumeMounts: [{name: cfg, mountPath: /etc/prometheus}]
      volumes: [{name: cfg, configMap: {name: prometheus}}]
---
apiVersion: v1
kind: Service
metadata: {name: prometheus, namespace: monitoring}
spec: {selector: {app: prometheus}, ports: [{port: 9090}]}
YAML

# prometheus-adapter on its chart's default rules, deliberately: what those
# rules call the metric is step 2.
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1
helm repo update prometheus-community >/dev/null 2>&1
helm install prometheus-adapter prometheus-community/prometheus-adapter \
  --version "$ADAPTER_CHART_VERSION" --namespace monitoring \
  --set prometheus.url=http://prometheus.monitoring.svc --set prometheus.port=9090 \
  --wait --timeout 6m >/dev/null 2>&1

# The model server: one sequence at a time, so a queue forms as soon as two
# requests overlap, and a 20-word answer takes about 8.6 seconds.
cat <<YAML | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata: {name: chat, namespace: serve}
spec:
  replicas: 1
  selector: {matchLabels: {app: chat}}
  template:
    metadata:
      labels: {app: chat}
      annotations: {prometheus.io/scrape: "true"}
    spec:
      containers:
      - name: sim
        image: $SIM_IMAGE
        args:
        - --port=8000
        - --model=demo-model
        - --served-model-name=demo-model
        - --mode=echo
        - --time-to-first-token=1s
        - --inter-token-latency=400ms
        - --max-num-seqs=1
        - --max-waiting-queue-length=1000
        ports: [{containerPort: 8000}]
        resources:
          requests: {cpu: 50m, memory: 64Mi}
        readinessProbe:
          httpGet: {path: /health/ready, port: 8000}
          periodSeconds: 2
---
apiVersion: v1
kind: Service
metadata: {name: chat, namespace: serve}
spec:
  selector: {app: chat}
  ports: [{port: 8000, targetPort: 8000}]
---
apiVersion: v1
kind: Pod
metadata: {name: cli, namespace: serve}
spec:
  containers:
  - {name: cli, image: $CLI_IMAGE, command: ["sleep", "infinity"]}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: chat, namespace: serve}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: chat}
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: {type: Utilization, averageUtilization: 50}
YAML

# The HPA "from the team runbook" for step 2. The metric name is the one most
# guides write, and it is wrong for this adapter.
cat > /root/hpa-queue.yaml <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: chat
  namespace: serve
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: chat
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Pods
    pods:
      metric:
        name: vllm_num_requests_waiting
      target:
        type: AverageValue
        averageValue: "2"
YAML

# llmload: open-loop load, one request every INTERVAL seconds, COUNT times,
# without waiting for answers. Users do not wait for each other, and it is the
# only shape under which a queue can build. Runs in the background; its summary
# lands in /tmp/llmload.out.
cat > /usr/local/bin/llmload <<'WRAP'
#!/bin/bash
INTERVAL=${1:-2}
COUNT=${2:-90}
P=$(awk 'BEGIN{for(i=1;i<=20;i++) printf "w%d ", i}')
nohup kubectl -n serve exec cli -- /bin/sh -c "
rm -f /tmp/lat.txt
for i in \$(seq 1 $COUNT); do
  ( curl -s -m 600 -o /dev/null -w '%{time_total} %{http_code}\n' \
      http://chat:8000/v1/chat/completions -H 'Content-Type: application/json' \
      -d '{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$P\"}]}' \
      >> /tmp/lat.txt ) &
  sleep $INTERVAL
done
wait
T=\$(wc -l < /tmp/lat.txt)
echo \"requests: \$T  failed: \$(grep -vc ' 200' /tmp/lat.txt)  median: \$(sort -n /tmp/lat.txt | awk -v t=\$T 'NR==int((t+1)/2){print \$1}')s  slowest: \$(sort -rn /tmp/lat.txt | head -1 | cut -d' ' -f1)s\"
" > /tmp/llmload.out 2>&1 &
echo "load started: one request every ${INTERVAL}s, $COUNT requests (about $(awk -v i=$INTERVAL -v c=$COUNT 'BEGIN{print int(i*c)}')s)."
echo "summary when it finishes: cat /tmp/llmload.out"
WRAP
chmod +x /usr/local/bin/llmload

# llmflood: N requests at once, straight to one Pod's IP, bypassing the Service.
cat > /usr/local/bin/llmflood <<'WRAP'
#!/bin/bash
# usage: llmflood POD [N]
POD=$1; N=${2:-9}
[ -z "$POD" ] && { echo "usage: llmflood POD [N]"; exit 1; }
IP=$(kubectl -n serve get pod "$POD" -o jsonpath='{.status.podIP}' 2>/dev/null)
[ -z "$IP" ] && { echo "no Pod called $POD in namespace serve"; exit 1; }
P=$(awk 'BEGIN{for(i=1;i<=20;i++) printf "w%d ", i}')
nohup kubectl -n serve exec cli -- /bin/sh -c "
for i in \$(seq 1 $N); do
  curl -s -m 600 -o /dev/null http://$IP:8000/v1/chat/completions -H 'Content-Type: application/json' \
    -d '{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$P\"}]}' &
done
wait" >/dev/null 2>&1 &
echo "$(date +%s) pod=$POD n=$N replicas=$(kubectl -n serve get deploy chat -o jsonpath='{.status.readyReplicas}')" >> /root/floods.log
echo "$N requests sent to $POD ($IP), bypassing the Service."
WRAP
chmod +x /usr/local/bin/llmflood

# llmstats: what each model server says about its own queue, next to the CPU
# that metrics-server reports for it.
cat > /usr/local/bin/llmstats <<'WRAP'
#!/bin/bash
printf "%-28s %6s %8s %8s\n" POD CPU RUNNING WAITING
TOP=$(kubectl -n serve top pods -l app=chat --no-headers 2>/dev/null)
kubectl -n serve get pods -l app=chat \
  -o jsonpath='{range .items[?(@.status.podIP)]}{.metadata.name}{" "}{.status.podIP}{"\n"}{end}' 2>/dev/null \
| while read -r POD IP; do
    M=$(kubectl -n serve exec cli -- curl -s -m 3 "http://$IP:8000/metrics" 2>/dev/null)
    RUN=$(echo "$M" | awk '/^vllm:num_requests_running/{print $2}')
    WAIT=$(echo "$M" | awk '/^vllm:num_requests_waiting/{print $2}')
    CPU=$(echo "$TOP" | awk -v p="$POD" '$1==p{print $2}')
    printf "%-28s %6s %8s %8s\n" "$POD" "${CPU:-?}" "${RUN:-?}" "${WAIT:-?}"
  done
WRAP
chmod +x /usr/local/bin/llmstats

BROKEN=
kubectl -n serve rollout status deploy/chat --timeout=240s >/dev/null 2>&1 || BROKEN=1
kubectl -n serve wait --for=condition=Ready pod/cli --timeout=240s >/dev/null 2>&1 || BROKEN=1
kubectl -n monitoring rollout status deploy/prometheus --timeout=240s >/dev/null 2>&1 || BROKEN=1
# The adapter is only useful once Prometheus has scraped the model server.
for _ in $(seq 1 60); do
  kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/serve/pods/*/vllm:num_requests_waiting" >/dev/null 2>&1 && break
  sleep 3
done
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/serve/pods/*/vllm:num_requests_waiting" >/dev/null 2>&1 || BROKEN=1
[ -n "$BROKEN" ] && touch /tmp/.initbroken
touch /tmp/.initfinished
