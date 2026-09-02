
To measure prefill on its own, switch decode off — set `inter-token-latency` to `0ms` and give prefill a per-token cost.

Reconfigure the simulator to:

```yaml
    latency-calculator: "per-token"
    prefill-overhead: "500ms"
    prefill-time-per-token: "20ms"
    inter-token-latency: "0ms"
```

Now `total ≈ 500ms + (prompt_tokens × 20ms)` — decode contributes nothing.

Measure a **short** prompt and a **long** one, and save both times to `/root/prefill-short` and `/root/prefill-long`.

<br>

<details><summary>Tip</summary>

```plain
/root/prompt.sh 10
/root/prompt.sh 100
```{{exec}}

Remember to restart the simulator after editing the ConfigMap — a mounted ConfigMap doesn't restart the Pod on its own.

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
    max-model-len: 4096
    max-num-seqs: 16
    latency-calculator: "per-token"
    prefill-overhead: "500ms"
    prefill-time-per-token: "20ms"
    inter-token-latency: "0ms"
YAML
```{{exec}}

```plain
kubectl rollout restart deployment/sim
kubectl rollout status deployment/sim
```{{exec}}

A 10-word prompt:

```plain
curl -s -o /dev/null -w '%{time_total}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"dummy-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$(/root/prompt.sh 10)\"}]}" \
  | tee /root/prefill-short
```{{exec}}

A 100-word prompt:

```plain
curl -s -o /dev/null -w '%{time_total}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"dummy-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$(/root/prompt.sh 100)\"}]}" \
  | tee /root/prefill-long
```{{exec}}

</details>

<br>

<details><summary>Info: what you just measured</summary>

Roughly `0.7s` versus `2.5s` — the same request shape, ten times the prompt, and prefill grew with it. Nothing about the *output* changed.

This is why long system prompts are expensive even when the answer is one word, and why production stacks work so hard to avoid re-prefilling text they've already seen. That's the entire motivation for **prefix caching**: if the first 2,000 tokens of every request are an identical system prompt, prefilling them every time is pure waste. In the formula it shows up as `n − n_cached`.

It's also why **chunked prefill** exists — a huge prefill would otherwise block the GPU and stall everyone else's decoding.

</details>
