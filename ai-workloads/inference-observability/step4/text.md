
You now have a query that detects saturation. The obvious next step is an alert on it — and the obvious problem is that **testing the alert requires producing the bad condition**, which usually means sustaining real load for as long as the alert's `for:` window.

The simulator can skip that. Started with `--fake-metrics`, it reports synthetic values instead of real ones, including generators that move over time:

```plain
oscillate:0:10:5s     smooth sine between 0 and 10, every 5s
ramp:0:40:30s         linear 0 -> 40 over 30s, then holds
squarewave:0:50:20s   flips between 0 and 50 every half period
```

**1.** Restart the simulator with a queue depth that ramps to 40 and stays there.

**2.** Add an alert rule to Prometheus: `HighInferenceQueueDepth`, firing when `vllm:num_requests_waiting > 20` for `30s`.

**3.** Watch it go `pending`, then `firing` — in about a minute, with no load generated at all.

<br>

<details><summary>Info: fake metrics replace real ones</summary>

This is deliberately not additive. From the docs: *"When specified, only these fake metrics will be reported — real metrics and fake metrics will never be reported together."*

So this mode is for exercising the **observability pipeline** — alert rules, routing, dashboards, autoscaler reactions — not for measuring the simulator. Swap it back off when you want real numbers again.

</details>

<details><summary>Tip</summary>

Prometheus loads alert rules from files referenced by `rule_files:`. Both the config and the rules can live in the same ConfigMap as separate keys.

A mounted ConfigMap updates on disk eventually, but `kubectl rollout restart deployment/prometheus` makes the reload immediate and deterministic.

Alert state is queryable like anything else — the `ALERTS` series carries an `alertstate` label.

</details>

<details><summary>Solution</summary>

Point the simulator at a synthetic, ramping queue depth:

```plain
cat <<'YAML' | kubectl apply -f -
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
          args:
            - --config
            - /config/config.yaml
            - --fake-metrics
            - '{"waiting-requests":"ramp:0:40:30s"}'
          ports:
            - containerPort: 8000
          volumeMounts:
            - name: config
              mountPath: /config
      volumes:
        - name: config
          configMap:
            name: sim-config
YAML
```{{exec}}

```plain
kubectl rollout status deployment/sim
```{{exec}}

Confirm the synthetic value is climbing:

```plain
curl -s http://localhost:30800/metrics | grep 'num_requests_waiting'
```{{exec}}

Now the alert rule, alongside the scrape config:

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prom-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 5s
      evaluation_interval: 5s
    rule_files:
      - /etc/prometheus/rules.yml
    scrape_configs:
      - job_name: vllm-sim
        static_configs:
          - targets: ['sim:8000']
  rules.yml: |
    groups:
      - name: llm-serving
        rules:
          - alert: HighInferenceQueueDepth
            expr: vllm:num_requests_waiting > 20
            for: 30s
            labels:
              severity: warning
            annotations:
              summary: "Inference queue depth is sustained above 20"
YAML
```{{exec}}

```plain
kubectl rollout restart deployment/prometheus
kubectl rollout status deployment/prometheus
```{{exec}}

Watch it arm and then fire:

```plain
curl -s -G http://localhost:30900/api/v1/query --data-urlencode 'query=ALERTS'
```{{exec}}

</details>
