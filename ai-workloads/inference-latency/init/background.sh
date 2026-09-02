#!/bin/bash

ctr -n k8s.io images pull ghcr.io/llm-d/llm-d-inference-sim:v0.11.2 >/dev/null 2>&1 \
  || crictl pull ghcr.io/llm-d/llm-d-inference-sim:v0.11.2 >/dev/null 2>&1 || true

# Deployed in echo mode on purpose: the response mirrors the prompt, so output
# length always equals input length. That makes the whole cost model
# predictable, which is what the later steps rely on.
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: sim-config
data:
  config.yaml: |
    port: 8000
    model: "dummy-model"
    mode: "echo"
    max-model-len: 4096
    max-num-seqs: 16
    latency-calculator: "per-token"
    prefill-overhead: "2s"
    prefill-time-per-token: "0ms"
    inter-token-latency: "200ms"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sim
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sim
  template:
    metadata:
      labels:
        app: sim
    spec:
      containers:
        - name: sim
          image: ghcr.io/llm-d/llm-d-inference-sim:v0.11.2
          args: ["--config", "/config/config.yaml"]
          ports:
            - containerPort: 8000
          volumeMounts:
            - name: config
              mountPath: /config
      volumes:
        - name: config
          configMap:
            name: sim-config
---
apiVersion: v1
kind: Service
metadata:
  name: sim
spec:
  type: NodePort
  selector:
    app: sim
  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30800
YAML

kubectl rollout status deployment/sim --timeout=180s

# helper the learner uses throughout: build a prompt of N words
cat > /root/prompt.sh <<'SH'
#!/bin/bash
# usage: prompt.sh <word-count>
yes token | head -"${1:-10}" | tr '\n' ' '
SH
chmod +x /root/prompt.sh

touch /tmp/.initfinished
