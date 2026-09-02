
An LLM server has a hard concurrency limit — `max-num-seqs`, the number of sequences it can decode at once. Past that, requests **queue**. Queue depth, not CPU, is what tells you a server is saturated.

Make that visible:

**1.** Edit `sim-config` so the simulator only handles **2** concurrent requests, and takes longer per token so the queue has time to build:

```yaml
    port: 8000
    model: "dummy-model"
    mode: "random"
    time-to-first-token: "2s"
    inter-token-latency: "300ms"
    max-num-seqs: 2
```

**2.** Restart the simulator to pick it up, fire enough concurrent requests to overwhelm it, and confirm `vllm:num_requests_waiting` actually rose above zero.

<br>

<details><summary>Info: why not autoscale on CPU</summary>

Watch CPU while the queue builds — it barely moves. The simulator is sleeping, and a real GPU server is waiting on the accelerator, not the CPU.

An HPA on CPU would therefore see a saturated, queueing server as *idle* and refuse to scale it. The signal that actually reflects saturation is `vllm:num_requests_waiting`, which is why LLM serving setups scale on queue depth or KV cache usage via custom metrics rather than the built-in CPU target.

</details>

<details><summary>Tip</summary>

Run curls in the background with `&` and `wait` for them, so they're genuinely concurrent rather than sequential.

`num_requests_waiting` is a gauge — it's only non-zero *while* requests are queued. To catch a spike after the fact, ask Prometheus for the maximum it saw over a window:

```plain
max_over_time(vllm:num_requests_waiting[10m])
```

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
    mode: "random"
    time-to-first-token: "2s"
    inter-token-latency: "300ms"
    max-num-seqs: 2
YAML
```{{exec}}

```plain
kubectl rollout restart deployment/sim
kubectl rollout status deployment/sim
```{{exec}}

Fire 12 requests at a server that can only run 2 at a time:

```plain
for i in $(seq 1 12); do
  curl -s -o /dev/null http://localhost:30800/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"dummy-model","messages":[{"role":"user","content":"queue me"}],"max_tokens":30}' &
done
wait
```{{exec}}

While that runs (or right after), check what CPU says versus what the queue says:

```plain
curl -s -G http://localhost:30900/api/v1/query \
  --data-urlencode 'query=max_over_time(vllm:num_requests_waiting[10m])'
```{{exec}}

```plain
curl -s -G http://localhost:30900/api/v1/query \
  --data-urlencode 'query=rate(vllm:generation_tokens_total[1m])'
```{{exec}}

The second one is your real throughput SLI: generated tokens per second.

</details>
