#!/bin/bash

# pre-pull both images so the steps aren't waiting on a registry
for img in ghcr.io/llm-d/llm-d-inference-sim:v0.11.2 prom/prometheus:v3.1.0; do
  ctr -n k8s.io images pull "$img" >/dev/null 2>&1 || crictl pull "$img" >/dev/null 2>&1 || true
done

# the simulator, configured with a KNOWN time-to-first-token - step 2 checks
# the metric against this value
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: sim-config
data:
  config.yaml: |
    port: 8000
    model: "dummy-model"
    mode: "random"
    time-to-first-token: "2s"
    inter-token-latency: "50ms"
    max-num-seqs: 5
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

touch /tmp/.initfinished
