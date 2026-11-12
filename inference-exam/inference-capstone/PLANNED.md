# One Model Server, Four Faults

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Troubleshooting a model server end to end: delivery, readiness, autoscaling, termination |
| **Domain** | Troubleshooting inference workloads (25%) |
| **Proposed backend** | `kubernetes-kubeadm-1node`, with the init from `autoscale-on-queue-depth` |
| **Feasibility** | Assembly. Each fault observed alone; the masking between them is **unverified** |

## What it teaches

The exam's troubleshooting domain is a fault you did not plant, on a workload you did not write, under a
clock. Here it is one Deployment, `chat`, that was "migrated from the old platform" and is wrong in four
ways, each from a spec in this folder and each silent or misleading in its own way. The skill is the
order: two of the faults cannot be seen until the one in front of them is fixed.

## The faults

Each was observed alone (kind, Kubernetes v1.37.0); the sources hold the evidence.

| # | Fault | What the learner sees | Source |
|---|---|---|---|
| A | Weights image volume names a tag that does not exist | `ImagePullBackOff`, while the container's own image is fine | [`model-weights-as-images`](../model-weights-as-images/) step 2 |
| B | Readiness probe on `/ready`; the simulator serves `/health/ready` | `Running 0/1`, `Readiness probe failed: HTTP probe failed with statuscode: 404`, a Service with no endpoints | Observed while writing [`draining-model-servers`](../draining-model-servers/) |
| C | HPA on `vllm_num_requests_waiting` | `<unknown>/2`, `FailedGetPodsMetric … could not find the metric` | [`autoscale-on-queue-depth`](../autoscale-on-queue-depth/) step 2 |
| D | `exec: [sleep, 60]` preStop in an image with no `sleep` | Nothing, until a rollout during a stream: the answer is cut, and `FailedPreStopHook` is an event | [`draining-model-servers`](../draining-model-servers/) step 3 |

## The order, and why

- **A hides B.** The container never starts, so the probe never runs. Fix A and the Pod goes
  `Running 0/1` instead of `Ready`: a second fault, not a slow start.
- **A hides C too.** With no running Pod there is no series, so the HPA is `<unknown>` whatever the
  name. Fixing A and B leaves it `<unknown>`, and a learner who checked the HPA first and blamed the
  missing Pods has to look again.
- **D shows only under a rollout.** The final check restarts the Deployment during a long stream and
  requires `[DONE]`.

## Step outline

1. **Nothing serves.** Gate: `chat` has a ready endpoint and answers a completion (A and B).
2. **It serves and will not scale.** Gate: the HPA is `ScalingActive=True` on a `Pods` metric (C).
3. **It scales and drops answers on every deploy.** Gate: a recorded stream that crossed a restart
   with `[DONE]`, and `lifecycle.preStop.sleep` set (D).

A `why` that names only the step's gate, never the remaining faults: the point is finding them.

## Must resolve before building

- **The masking claims.** Both "A hides" bullets follow from how Pods and scraping work and were not
  observed with the faults combined. Plant all four on one cluster and confirm each symptom appears in
  the order above.
- **The three source specs first.** This lab reuses their inits and helpers (the stream recorder, the
  Prometheus and adapter install). Build it after them.
- **Init time.** Prometheus, adapter, metrics-server and the weights image together; measure on the
  backend.

## Cross-links

- [`cka/broken-cluster-capstone`](../../cka/broken-cluster-capstone/): the same shape at the cluster
  level, where the scheduler hides the other faults.
- [`ckne/inference-pool-by-hand`](../../ckne/inference-pool-by-hand/) step 3: every object green,
  every request failing, one layer further out.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
