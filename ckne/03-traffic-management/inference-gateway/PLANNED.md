# The Router That Reads the Request

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Implementing Advanced Load Balancing for Inference Workloads |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Ready — verified on a live cluster.** See the spike results below. |

## What it teaches

The direct sequel to [`llm-routing`](../../llm-routing/), which ends on two problems it cannot
solve: a load balancer that cannot see a model server's queue, and a model name that lives in
the JSON body where `HTTPRoute` structurally cannot match on it. The Gateway API Inference
Extension exists because both are the same problem — routing that has to *understand* the
request rather than merely forward it — and this lab is the answer to the lab already shipped.

## The finding at its heart

The measured difference is not subtle, and neither is what happens when the router dies.

## Spike results — measured, not assumed

Run on a kubeadm-shaped cluster on 2026-09-16. Forty requests, open-loop, one every 0.4s,
against one fast replica and one `--max-num-seqs=1` replica:

```
round-robin (plain Service)      failed 25/40   median 60.00s   p90 60.00s
endpoint picker (InferencePool)  failed  0/40   median  0.40s   p90  0.41s
```

The EPP's own plugin config names `queue-scorer` with `queueDepthThreshold: 5` — it is scoring
on `vllm:num_requests_waiting`, the metric `llm-routing` step 4 identifies and cannot act on.

**Footprint, once the chart's defaults are overridden: 57MB of memory for the picker and its
Envoy together**, and ~93MB of images.

## Step outline

1. **Reproduce, then fix.** Same uneven replica pair and the same open-loop generator as
   `llm-routing`. Measure round-robin, install the `InferencePool` and EPP, measure again. The
   numbers above are the payoff, and they are large enough that nobody has to squint.
2. **Why it works.** The EPP scrapes each replica's own metrics and picks per request.
   Contrast explicitly with `llm-routing` step 2's least-request, which counted what the proxy
   had dispatched — the queue was invisible from outside the model server, and this is what
   seeing inside it is worth.
3. **Body-based routing.** The model name routes on its own, and the `x-model` header
   workaround `llm-routing` step 3 forces on the learner gets deleted. Requires the Body-Based
   Router, now a separate component — see below.
4. **Kill the picker.** `endpointPickerRef.failureMode` defaults to `FailOpen`, which does
   **not** mean what most readers assume. Scale the EPP to zero: every request returns
   `503 no healthy upstream` in about a millisecond. Fail-open means the ext_proc filter stops
   blocking, not that the gateway finds its own endpoints — the picker is a hard dependency on
   the request path, and the name actively misleads.

> Step 4 was guessed wrong during design. The expectation was a silent degradation to
> round-robin; the reality is a hard 503. Worth recording, because the wrong version is the
> intuitive one and a learner will arrive holding it.

## What changed upstream, and what it costs this lab

The project split in August–September 2026 and `llm-routing`'s closing note is now out of date:

| Component | Now lives in |
|---|---|
| `InferencePool` API, Endpoint Picker Protocol, conformance tests | `kubernetes-sigs/gateway-api-inference-extension` (v1.6.1) |
| Endpoint Picker, `InferenceObjective`, `InferenceModelRewrite` | `llm-d/llm-d-router` (v0.10.0) |
| Body-Based Router | `llm-d/llm-d-inference-payload-processor` (v0.1.0) |

**Envoy Gateway is not a conformant implementation** — the listed ones are Istio, Agentgateway
and NGINX Gateway Fabric — so this lab cannot reuse `llm-routing`'s gateway installation.
llm-d Router's **standalone mode** avoids the question entirely: it runs its own Envoy beside
the EPP, needs no Gateway API infrastructure, and still creates a genuine `InferencePool` with
a real `endpointPickerRef`. That is what the spike used and what the lab should use.

**The Helm chart will not schedule as shipped.** Its defaults are production GPU-fleet sizing —
8 CPU / 8Gi for the EPP, 4 CPU / 8Gi for its Envoy, so 12 CPU and 16Gi for the router alone. It
sits `Pending` on `Insufficient cpu, Insufficient memory`. The init script must override to
roughly `200m` / `256Mi`, and the lab text should say why rather than hiding it in a values file:
a chart sized for a GPU fleet is a real thing learners will meet.

## Must resolve before building

- **The Body-Based Router for step 3.** The spike covered the endpoint picker but not BBR,
  which is a separate component at v0.1.0 and much younger. If it does not install cleanly,
  step 3 becomes a two-step lab about queue-aware routing only, and body-based routing moves to
  the finish notes. Decide before writing step 3, not during.
- **Whether to pin `main` or `v0.10.0`** for the EPP image. The chart defaults to `main`, which
  is not a thing a lab should depend on; the spike confirmed `v0.10.0` is pullable anonymously.
- **Image pull time on the real backend.** ~93MB across three images plus the sim; fine locally,
  worth timing on Killercoda before setting the init timeout.

## Cross-links

- **Sequel to [`llm-routing`](../../llm-routing/)**, and should say so in its intro. That lab's
  step 3 closing note points forward to this one and needs updating for the split above.
- Reuses `llm-d-inference-sim` and the `llmload` open-loop generator already built there.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
