
The simulator was started with a **known** time to first token:

```plain
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}'
```{{exec}}

`time-to-first-token: "2s"`. That's the ground truth — so you can write a p95 latency query and actually check whether it's right, which you can never do against a real model.

Send some traffic, then compute p95 TTFT from the histogram and save the value to `/root/ttft-p95`.

<br>

<details><summary>Info: the metrics that matter for serving</summary>

| Metric | Meaning |
|---|---|
| `vllm:time_to_first_token_seconds` | **TTFT** — prefill latency. What a user perceives as "did it start answering?" |
| `vllm:time_per_output_token_seconds` | **TPOT** — decode speed. Perceived as how fast text streams |
| `vllm:e2e_request_latency_seconds` | total request time |
| `vllm:request_queue_time_seconds` | time spent waiting, before any work started |

TTFT and TPOT are the two SLIs LLM serving is actually judged on. A single "request duration" number hides both: a fast TTFT with slow decode feels completely different from the reverse, even at identical totals.

</details>

<details><summary>Tip</summary>

Histograms are exposed as `_bucket` series with an `le` label. The standard shape is:

```plain
histogram_quantile(0.95, sum(rate(<metric>_bucket[5m])) by (le))
```

URL-encode the query, or use `curl --data-urlencode` with the `/api/v1/query` endpoint.

</details>

<details><summary>Solution</summary>

Generate some requests to populate the histogram:

```plain
for i in $(seq 1 10); do
  curl -s -o /dev/null http://localhost:30800/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"dummy-model","messages":[{"role":"user","content":"hello"}],"max_tokens":20}'
done
```{{exec}}

Give Prometheus a couple of scrapes to pick them up:

```plain
sleep 15
```{{exec}}

Now the p95:

```plain
curl -s -G http://localhost:30900/api/v1/query \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(vllm:time_to_first_token_seconds_bucket[5m])) by (le))'
```{{exec}}

Pull out just the number and save it:

```plain
curl -s -G http://localhost:30900/api/v1/query \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(vllm:time_to_first_token_seconds_bucket[5m])) by (le))' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["result"][0]["value"][1])' \
  | tee /root/ttft-p95
```{{exec}}

</details>

<br>

> The answer won't be exactly `2`. Histograms record which **bucket** an observation fell into, not the observation itself, so a quantile is interpolated within a bucket. With boundaries at `1.0` and `2.5`, a true 2s TTFT lands in the `2.5` bucket and p95 estimates somewhere inside it. That interpolation error is inherent to Prometheus histograms — worth seeing once with a known input, so you recognise it later with an unknown one.
