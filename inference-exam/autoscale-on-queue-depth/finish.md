## What you found

| Step | The HPA said | The model server said |
|---|---|---|
| CPU target | `cpu: 8%/50%`, 1 replica | 23 waiting, and climbing |
| runbook metric name | `<unknown>/2`, `FailedGetPodsMetric` | the same queue, unread |
| colon name | `10750m/2`, scaled 1 → 4 → 5 | the backlog |
| after the scale-up | at its maximum, satisfied | one replica with 35 waiting, four with none |
| one replica flooded | `1333m/2` over six replicas, nothing to do | eight waiting on one replica |

**CPU measures the wrong resource.** A model server waits on its accelerator, and waiting is free. The HPA's default metric reads a replica with a deep queue as idle.

**The metric's name is whatever the adapter says it is.** On prometheus-adapter's default rules `vllm:num_requests_waiting` keeps its colon. The underscore form most guides write is a metric that does not exist, and the HPA's only complaint is a condition and an event: no Pod fails, and it never scales. `kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1` lists what the HPA can actually see.

**The rescale event names the metric that drove it.** `New size: 4; reason: pods metric vllm:num_requests_waiting above target` is how you tell which metric is in charge of an HPA you did not write.

**New replicas take none of the backlog.** A queued request has already been routed to one process, and nothing can move it. Autoscaling adds capacity for requests that have not arrived yet; the users already queued wait exactly as long as they would have.

**`AverageValue` is an average.** One deep queue among idle replicas reads as a healthy fleet. Both of the last two findings are about where work lands, which the HPA cannot see and cannot change.

## The shape of it

> Autoscaling answers "is there enough capacity?". The users in a queue are asking "is there capacity *here*?", and only the router can answer that.

Queue depth is the right signal to scale a model server on. It is the wrong signal to route on after the fact, because by the time it is high the requests that made it high are committed. That is the division of labour between this lab and the inference gateway: the HPA decides how many replicas, the endpoint picker decides which one.

## Where to go next

- **[`ckne/inference-gateway`](https://killercoda.com/kylelaw/course/ckne/inference-gateway)** — routing that reads each replica's queue, the half of the problem this lab could only point at.
- **[`ckne/llm-routing`](https://killercoda.com/kylelaw/course/ckne/llm-routing)** — the same queue-versus-CPU table from the routing side, and why least-request balancing does not fix it.
- **[`ai-workloads/inference-observability`](https://killercoda.com/kylelaw/course/ai-workloads/inference-observability)** — these metrics in PromQL, and alerting on them.

> **Versions.** Run on Kubernetes v1.37 with `llm-d-inference-sim` v0.11.2, prometheus-adapter chart 5.4.0 (adapter v0.12.0) and metrics-server v0.8.0. A different adapter chart version may ship different default rules, and with them a different name for the metric.
