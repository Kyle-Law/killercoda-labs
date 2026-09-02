
Passing flags on the command line doesn't scale — real deployments keep this config in a **ConfigMap**.

Switch the simulator to a config file and put it in **echo mode**, where the response mirrors the input instead of generating synthetic text. That makes its behaviour deterministic, which is exactly what you want when testing surrounding infrastructure.

Create a ConfigMap named `sim-config` holding a `config.yaml` with:

```yaml
port: 8000
model: "dummy-model"
mode: "echo"
time-to-first-token: 200
inter-token-latency: 20
```

Mount it at `/config` and start the simulator with `--config /config/config.yaml` instead of the inline flags.

Then confirm echo mode is live: send a distinctive phrase and get it back.

<br>

<details><summary>Info: the two response modes</summary>

- **`random`** (the default) — synthesises a response of a plausible length from built-in sentences. Realistic, but the content is arbitrary.
- **`echo`** — returns the input back. Useless as "AI", ideal for testing: you can assert on exactly what comes out.

`time-to-first-token` and `inter-token-latency` are in milliseconds and model the prefill and decode phases separately — the next steps lean on that.

</details>

<details><summary>Tip</summary>

```plain
kubectl create configmap -h
```{{exec}}

Mounting a ConfigMap needs a `volumes` entry plus a `volumeMounts` entry, and the container's `args` have to point at the mounted path.

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
    time-to-first-token: 200
    inter-token-latency: 20
YAML
```{{exec}}

```plain
kubectl patch deployment sim --type merge -p '{
  "spec": {"template": {"spec": {
    "containers": [{
      "name": "sim",
      "args": ["--config", "/config/config.yaml"],
      "volumeMounts": [{"name": "config", "mountPath": "/config"}]
    }],
    "volumes": [{"name": "config", "configMap": {"name": "sim-config"}}]
  }}}
}'
```{{exec}}

```plain
kubectl rollout status deployment/sim
```{{exec}}

Now the response should contain your own words back:

```plain
curl -s http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"dummy-model","messages":[{"role":"user","content":"echo-mode-works"}]}'
echo
```{{exec}}

</details>
