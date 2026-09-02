
Now the mirror image: switch prefill's per-token cost off and turn decode on.

```yaml
    prefill-overhead: "500ms"
    prefill-time-per-token: "0ms"
    inter-token-latency: "20ms"
```

Now `total ≈ 500ms + (output_tokens − 1) × 20ms`, and prompt length no longer affects prefill at all.

In echo mode the response mirrors the prompt, so a longer prompt still means a longer **output**. Measure a short and long prompt again — but this time the growth you see is **decode**, not prefill.

Save the two times to `/root/decode-short` and `/root/decode-long`.

<br>

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
    prefill-time-per-token: "0ms"
    inter-token-latency: "20ms"
YAML
```{{exec}}

```plain
kubectl rollout restart deployment/sim
kubectl rollout status deployment/sim
```{{exec}}

```plain
curl -s -o /dev/null -w '%{time_total}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"dummy-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$(/root/prompt.sh 10)\"}]}" \
  | tee /root/decode-short
```{{exec}}

```plain
curl -s -o /dev/null -w '%{time_total}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"dummy-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$(/root/prompt.sh 100)\"}]}" \
  | tee /root/decode-long
```{{exec}}

</details>

<br>

<details><summary>Info: why the two phases need different fixes</summary>

Prefill and decode are bottlenecked on different things. Prefill processes the whole prompt at once — it's compute-heavy and parallel. Decode produces one token at a time, each depending on the last, so it's serial and bound by memory bandwidth rather than compute.

That's why they don't respond to the same remedies:

| | Prefill | Decode |
|---|---|---|
| Grows with | input length | output length |
| Bound by | compute | memory bandwidth |
| Helped by | prefix caching, chunked prefill | larger batches, speculative decoding |

It's also the entire argument for **disaggregated prefill/decode** — running the two phases on separately-tuned hardware and shipping the KV cache between them, which is what the `kv-cache-transfer-latency` setting models.

</details>
