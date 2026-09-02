
<br>

An LLM server fails differently from a web server, so it needs different signals. Request rate and CPU tell you almost nothing; what matters is **time to first token**, **time per output token**, **queue depth**, and **KV cache pressure**.

A vLLM simulator is already running in this cluster, emitting the same Prometheus metric names a real vLLM emits — but with one advantage a real one can't give you: **its latency is configured, so you know the right answer in advance.** That makes it possible to check a p95 query against ground truth instead of hoping it's correct.

You'll scrape it with Prometheus, query the metrics that matter for serving, watch a queue saturate while CPU stays flat, and finish by proving an alert fires — without generating any load at all.

> This scenario uses a plain Prometheus Deployment with a static scrape config, to keep the focus on the metrics. For the Operator, `ServiceMonitor` and RBAC machinery, see the *Install the Prometheus Operator* scenario.
