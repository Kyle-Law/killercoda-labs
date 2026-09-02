
You've measured each phase on its own. Now turn **both** on and predict a request before sending it.

Configure:

```yaml
    prefill-overhead: "500ms"
    prefill-time-per-token: "20ms"
    inter-token-latency: "20ms"
```

Then, for a **50-word** prompt, work out the expected total from the cost model *before* running anything. Write your prediction (in seconds) to `/root/prediction`, then measure the real time into `/root/measured`.

<br>

<details><summary>Tip: do the arithmetic</summary>

In echo mode `output_tokens == prompt_tokens`, so with `n` tokens:

```
prefill = 500ms + n × 20ms
decode  = (n − 1) × 20ms
total   = prefill + decode
```

The helper produces one word per token, so a 50-word prompt is roughly `n = 50`.

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
    inter-token-latency: "20ms"
YAML
```{{exec}}

```plain
kubectl rollout restart deployment/sim
kubectl rollout status deployment/sim
```{{exec}}

The arithmetic for `n = 50`:

```
prefill = 0.5s + 50 × 0.02s = 1.5s
decode  = 49 × 0.02s        = 0.98s
total                       ≈ 2.5s
```

```plain
echo "2.5" > /root/prediction
```{{exec}}

```plain
curl -s -o /dev/null -w '%{time_total}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"dummy-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$(/root/prompt.sh 50)\"}]}" \
  | tee /root/measured
```{{exec}}

</details>

<br>

<details><summary>Info: if your prediction was close but not exact</summary>

Token counts rarely match word counts exactly — real tokenizers split on subwords, so "tokenization" might be two or three tokens while "the" is one. The simulator's built-in tokenizer is a simple regex splitter, so one word per token is close but not guaranteed.

That gap matters in production too: capacity planning done in *words* is wrong by whatever your tokenizer's ratio happens to be, and that ratio varies by language. Non-English text often costs substantially more tokens for the same content.

</details>
