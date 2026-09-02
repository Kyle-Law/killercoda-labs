
The simulator exposes `/metrics` in Prometheus format, using the **same metric names a real vLLM emits**. That's the point: dashboards, recording rules and alerts you build against the simulator work unchanged against production.

Scrape it, drive some traffic through it, and scrape it again. Save the second scrape to `/root/metrics.txt`.

<br>

<details><summary>Info: the metrics that matter for serving</summary>

| Metric | What it tells you |
|---|---|
| `vllm:num_requests_running` | requests being decoded right now |
| `vllm:num_requests_waiting` | queue depth — the real autoscaling signal |
| `vllm:prompt_tokens_total` | cumulative input tokens |
| `vllm:generation_tokens_total` | cumulative output tokens |
| `vllm:kv_cache_usage_perc` | KV cache pressure |
| `vllm:time_to_first_token_seconds` | prefill latency histogram |

Note that queue depth, not CPU, is the meaningful scaling signal for inference — which is why an HPA on CPU behaves so badly for LLM serving.

</details>

<details><summary>Solution</summary>

Look at it before any traffic:

```plain
curl -s http://localhost:30800/metrics | grep '^vllm:' | head -20
```{{exec}}

Send a handful of requests:

```plain
for i in $(seq 1 5); do
  curl -s -o /dev/null http://localhost:30800/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"dummy-model","messages":[{"role":"user","content":"generate some tokens please"}]}'
done
echo "sent 5 requests"
```{{exec}}

Scrape again and save it:

```plain
curl -s http://localhost:30800/metrics > /root/metrics.txt
grep -E '^vllm:(prompt_tokens_total|generation_tokens_total|num_requests_running)' /root/metrics.txt
```{{exec}}

The token counters have moved.

</details>

<br>

<details><summary>Where this goes next</summary>

In a real cluster you'd point Prometheus at this with a `ServiceMonitor` — the simulator is a realistic scrape target for building that pipeline before any GPU exists. The `observability/prometheus-operator` scenario in this repo covers the Operator and ServiceMonitor side.

</details>
