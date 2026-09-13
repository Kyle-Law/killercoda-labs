
<br>

**A streaming response breaks what a timeout means.** For a normal request, "15 seconds and nothing back" is a clean failure signal. For a generation, the response started immediately and is arriving steadily — it just takes longer than any duration that made sense for a REST call. Envoy's 15s default truncated the answer mid-sentence and still reported `200`, with `curl` exiting successfully. Set `timeouts` per route, on the routes that stream, and remember every hop has its own: proxy, ingress, mesh, client SDK. The shortest one wins silently.

**Round-robin balances request *count*, which is only a proxy for load when requests cost the same.** They don't here. One replica taking 8 concurrent and another taking 1 received identical shares, producing a 0.4s median against a 33s p90 — two completely different services behind one address. An average would have concealed it entirely.

**Least-request does not fix this, and the reason is the useful part.** It counts requests the proxy has dispatched and is still awaiting. A model server accepts every request instantly and queues it *internally* — ten deep, while the proxy sees one request in flight, exactly as it sees one to the idle replica. **The queue is invisible from outside the process.** No generic load-balancing algorithm can route around a backlog it cannot observe.

**The model name lives where an HTTP router cannot look.** `HTTPRoute` matches on `headers`, `method`, `path` and `queryParams`; the OpenAI API puts the model in the JSON body. Lifting it into a header works but requires every caller to duplicate a field that is already in the request, with nothing keeping the two consistent — so it only holds for clients you control.

**CPU is the wrong autoscaling metric for GPU-bound work.** Ten queued requests at ~0 millicores. A 70%-CPU HPA would never fire on the replica that is drowning, and might scale it down. `vllm:num_requests_waiting` is the signal: zero when healthy, and every unit above zero is a user waiting. It is also *leading* — the queue grows before latency does, so you add capacity before anyone is harmed rather than after.

## Where this goes in production

Steps 2 and 3 are the same problem, and the ecosystem solves them in one place. The [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/) adds an `InferencePool` and an **endpoint picker** the gateway consults per request — it reads the body for the model name *and* scrapes each replica's queue metrics to pick the least-loaded one. Both gaps close together because both need a router that understands the request instead of merely forwarding it.

## Where to go next

- [`ai-workloads/inference-sim`](../../ai-workloads/inference-sim/) — the simulator itself: config, probes, failure injection, and the full vLLM metric set
- [`ai-workloads/inference-latency`](../../ai-workloads/inference-latency/) — measuring TTFT and inter-token latency properly
- [`ckne/httproute-in-depth`](../httproute-in-depth/) — the Gateway API mechanics underneath this: listeners, match precedence, weighted splitting
- [`observability/prometheus-operator`](../../observability/prometheus-operator/) — scraping these metrics with a `ServiceMonitor`, the first step to an HPA that reads them

> `ckne/README.md` — this lab covers the CKNE "Optimizing LLM Traffic" objective in Advanced Traffic Management.
