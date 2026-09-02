
Passing flags on the command line doesn't scale — real deployments keep this config in a **ConfigMap**.

Switch the simulator to a config file and put it in **echo mode**, where the response mirrors the input instead of generating synthetic text. That makes its behaviour deterministic, which is exactly what you want when testing surrounding infrastructure.

**1.** Create a ConfigMap named `sim-config` holding a `config.yaml`:

```yaml
port: 8000
model: "dummy-model"
mode: "echo"
time-to-first-token: "200ms"
inter-token-latency: "20ms"
```

**2.** Then edit the Deployment so the container reads that file instead of inline flags. Three things change in `spec.template.spec`:

```yaml
    spec:
      containers:
        - name: sim
          image: ghcr.io/llm-d/llm-d-inference-sim:v0.11.2
          args: ["--config", "/config/config.yaml"]     # <- replaces the inline flags
          ports:
            - containerPort: 8000
          volumeMounts:                                  # <- add
            - name: config
              mountPath: /config
      volumes:                                           # <- add
        - name: config
          configMap:
            name: sim-config
```

Then confirm echo mode is live: send a distinctive phrase and get it back.

<br>

<details><summary>Info: the two response modes</summary>

- **`random`** (the default) — synthesises a response of a plausible length from built-in sentences. Realistic, but the content is arbitrary.
- **`echo`** — returns the input back. Useless as "AI", ideal for testing: you can assert on exactly what comes out.

`time-to-first-token` and `inter-token-latency` model the prefill and decode phases separately. **They are durations and need a unit** — `"200ms"`, `"2s"`. A bare number is rejected.

</details>

<details><summary>Tip</summary>

```plain
kubectl create configmap -h
kubectl edit deployment sim
```{{exec}}

A ConfigMap can be created from a literal file with `--from-file`, or declared as YAML.

</details>

<details><summary>Solution</summary>

```plain
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
    time-to-first-token: "200ms"
    inter-token-latency: "20ms"
YAML
```{{exec}}

Now the Deployment. You can `kubectl edit deployment sim` and make the three changes by hand, or just apply the finished version:

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
YAML
```{{exec}}

```plain
kubectl rollout status deployment/sim
```{{exec}}

The response should now contain your own words back:

```plain
curl -s -w '\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"dummy-model","messages":[{"role":"user","content":"echo-mode-works"}]}'
```{{exec}}

</details>
