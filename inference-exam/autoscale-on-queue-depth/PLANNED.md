# Scaling on the Queue, Not the CPU

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | HPA on a model server's own metric through prometheus-adapter: the name, the wiring, and what an average hides |
| **Domain** | Autoscaling (10%) |
| **Proposed backend** | `kubernetes-kubeadm-1node`; init installs metrics-server, a plain Prometheus with pod discovery, and prometheus-adapter |
| **Feasibility** | Steps 1-3 **ready** (observed below). Step 4 observed, its framing to settle |

## What it teaches

[`ckne/llm-routing`](../../ckne/llm-routing/) step 4 ends on the right answer, scale on
`vllm:num_requests_waiting`, and stops before wiring it. This lab is the wiring, and the wiring is where
it goes wrong: the metric's name changes between Prometheus and the HPA in the way most guides assume,
except it doesn't.

## The finding at its heart

**On prometheus-adapter's default rules the metric is `vllm:num_requests_waiting`, colon and all.**
The underscore form that guides (and this repo's own `llm-routing`, until corrected) write in the HPA,
`vllm_num_requests_waiting`, is NotFound, and the HPA reports `<unknown>` with a condition that names
the metric it could not find. The apiserver accepts the colon in an HPA metric name, and the HPA works.

And once it works: **`AverageValue` is an average.** One replica with eight requests queued among five
idle ones reads `1333m` against a target of `2`, and nothing scales. Autoscaling cannot fix a routing
problem; that is what [`ckne/inference-gateway`](../../ckne/inference-gateway/) is for.

## Observed (kind, Kubernetes v1.37.0, simulator v0.11.2, prometheus-adapter chart 5.4.0 / app v0.12.0, metrics-server v0.8.0)

Simulator: `--max-num-seqs=1 --time-to-first-token=1s --inter-token-latency=400ms`, CPU request `50m`.
Load: 12 concurrent 20-word requests per round.

**CPU target (`averageUtilization: 50`):**

| t | HPA | `kubectl top` | `num_requests_waiting` | Replicas |
|---|---|---|---|---|
| 30s | `cpu: 6%/50%` | 4m | 8 | 1 |
| 60s | `cpu: 10%/50%` | 5m | 4 | 1 |
| 90s | `cpu: 8%/50%` | 4m | 1 | 1 |

**The name.** The adapter's default rules exposed 30 custom metrics, including
`pods/vllm:num_requests_waiting`, `pods/vllm:num_requests_running` and `pods/vllm:kv_cache_usage_perc`.

| HPA `metric.name` | `kubectl get --raw …/pods/*/<name>` | HPA |
|---|---|---|
| `vllm_num_requests_waiting` | `NotFound: the server could not find the metric vllm_num_requests_waiting for pods` | `<unknown>/2`, `ScalingActive=False FailedGetPodsMetric: … unable to fetch metrics from custom metrics API: the server could not find the metric vllm_num_requests_waiting for pods` |
| `vllm:num_requests_waiting` | a `MetricValueList` per Pod | works (below) |

**Pods metric, `AverageValue: "2"`, max 5, same load:**

| t | HPA | Replicas |
|---|---|---|
| 15s | `3/2` | 4 |
| 30s | `1400m/2` | 5 (`ScalingLimited=True TooManyReplicas`) |
| 91s | `0/2` | 5 (`AbleToScale=True ScaleDownStabilized`) |

**The hot replica.** Six replicas, nine requests sent straight to one Pod's IP: the HPA read `1333m/2`
(eight waiting across six Pods) and stayed at 6.

## Step outline

1. **A full queue and an idle CPU.** A CPU-target HPA is already in place. Run the load, watch the HPA
   read single-digit percent while `num_requests_waiting` climbs. Gate: an answer naming both readings.
   Short, because `llm-routing` step 4 already argued it; here it is the HPA itself, not a table.
2. **The name from the runbook.** `/root/hpa-queue.yaml` is the HPA "from the team runbook", with the
   underscore name. Apply it, meet `<unknown>`, read the condition, and find the real name by asking the
   API (`kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1`). Gate: an HPA of type `Pods` with
   `ScalingActive=True`.
3. **It scales.** Run the load; the HPA goes 1 → max within about 30 seconds. Gate: more than one
   replica *and* the metric type is `Pods` (so a CPU HPA cannot pass by luck).
4. **The replica the average hides.** Send a backlog straight to one Pod. Read the per-Pod values from
   the API, then the HPA's average, and say why nothing scales. Gate: an answer naming the average.

## Must resolve before building

- **Step 4's framing.** As observed it is a discussion step with a reading. The alternative is the
  scale-down window: the HPA sat at 5 with `ScaleDownStabilized` and the documented default is 300s.
  Not measured here; [`cka/hpa-without-requests`](../../cka/hpa-without-requests/) needs the same
  measurement, so take it once for both.
- **Queued requests do not move.** Reasoning says requests already queued inside the hot replica stay
  there when new replicas arrive, so scaling helps only later arrivals. Not measured; measure before
  saying it in the text.
- **KEDA as the alternative.** Not tried. A `ScaledObject` with the Prometheus scaler takes a PromQL
  query, so the naming trap does not exist there, and that is worth a Tip once seen.
- **The adapter's default rules on the pinned chart.** Chart 5.4.0 exposed the colon name with no
  custom rules. Pin the chart; a different default rule set changes step 2's whole premise.
- **Prometheus's relabelling.** The adapter associates a series with a Pod by `namespace` and `pod`
  labels; the spike's scrape config added both from pod discovery. Keep that config, and its RBAC
  (`get/list/watch pods`).
- **Image pulls on the backend.** `prom/prometheus:v3.1.0` is already used by `ai-workloads/`. The
  adapter image and metrics-server (step 1 only) are new to this backend; time the init.

## Cross-links

- [`ckne/llm-routing`](../../ckne/llm-routing/) step 4: why this metric, not CPU.
- [`ai-workloads/inference-observability`](../../ai-workloads/inference-observability/): the same
  metrics in PromQL.
- [`cka/hpa-without-requests`](../../cka/hpa-without-requests/): the other `<unknown>`, with a different
  cause and a different condition.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
