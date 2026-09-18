# The Load Balancer Is Working Exactly As Configured

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Optimizing LLM Traffic |
| **Mapped tech** | Gateway API (Inference Extension) + Istio |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` (see resource budget below) |
| **Feasibility** | **Ready — built and measured end to end on a 3-node kubeadm + Cilium cluster.** |

## What it teaches

The sequel to [`llm-routing`](../../llm-routing/), which ends on a load balancer that cannot see a
model server's queue. The Gateway API Inference Extension can see it — and this lab is about
discovering that seeing it is not the same as acting on it.

The endpoint picker scores each replica on prefix-cache match, queue depth and KV-cache usage,
then routes to the highest weighted total. With the default weights, **a replica with a thirty-deep
queue still wins over an idle one**, every time, and the configuration is behaving exactly as
specified.

## The finding at its heart

`prefix ×3, queue ×2, KV ×2`. Each scorer returns 0 to 1 relative to the other replicas, so the
prefix owner with the worst possible queue scores `3 + 0 + 2 = 5` and a completely idle replica
scores `0 + 2 + 2 = 4`.

**A queue can subtract at most 2 points. A prefix match is worth 3. Queue depth therefore cannot
win — not under heavy load, not ever.** Nothing is broken, nothing logs a warning, and the fix is a
single integer.

## Step outline

1. **Prove the path, using a failure.** One request through Gateway → EPP → simulator. Then send a
   model name that does not exist: the `404 The model ... does not exist` is *better* evidence than
   a success, because that error can only have come from the simulator at the far end — it proves
   every hop, including the picker.
2. **Long prompts land on one replica, and that is correct.** Establish prefix affinity as a
   feature before breaking it: repeated long system prompts should reuse a warm cache, and sending
   them elsewhere would be worse. Also establish the measurement trap — a short prompt spreads
   evenly, not because affinity is off but because the prompt is smaller than one hashed prefix
   chunk.
3. **Make a queue exist, and watch it lose.** The simulator answers instantly by default, so no
   queue ever forms and the queue scorer never engages — add `--time-to-first-token`,
   `--inter-token-latency` and `--max-num-seqs=2`. Now run the load again: every request still goes
   to the prefix owner while two replicas sit idle. Work out why from the weights before being told.
4. **Change one integer.** Prefix weight 3 → 1 in the EPP ConfigMap, restart, re-run: traffic
   spreads. Then the trap — `helm upgrade` resets that ConfigMap, so a weight that lives only in a
   `kubectl edit` is a fix that silently reverts. It has to go into Helm values.

## Measured results to build the checks against

From a 3-node kubeadm + Cilium cluster, 3 simulator replicas, counted per replica:

| Setup | Load | Per-replica | Reading |
|---|---|---|---|
| no latency, prefix weight 3 | `60 diff` | 19 / 24 / 17 | even — every prompt is unique, no affinity to exploit |
| no latency, prefix weight 3 | `60 same` ("hello") | 20 / 17 / 23 | even — the prompt is shorter than one prefix chunk |
| no latency, prefix weight 3 | `30 long`, serial | 0 / 0 / 30 | prefix affinity, working |
| no latency, prefix weight 3 | `60 long`, ×10 | 0 / 0 / 60 | still one replica — replies are instant, so no queue forms |
| **latency + max 2 seqs, weight 3** | `60 long`, ×10 | **0 / 60 / 0** | **the owner keeps everything despite its queue** |
| latency + max 2 seqs, weight 1 | `60 long`, ×10 | 22 / 18 / 20 | spreads — and the owner gets the fewest |

The fifth row is the lab. The fourth is why the lab needs step 3's latency patch to exist at all.

> An untested middle case worth making step 4's "predict before you run": **prefix weight 2**,
> expected to give the owner more than a third but not all of it, around 30 / 15 / 15. If it does,
> the weights are a continuum rather than a switch, which is the more useful mental model.

## Migration notes — runbook to lab

Built from a working runbook, so most of this is settled. What changes:

- **Phases 1–6 become `init/background.sh`.** Gateway API CRDs, GAIE CRDs, Istio, the simulator
  Deployment, the InferencePool Helm chart, the Gateway and HTTPRoute. `foreground.sh` shows
  progress dots as [`llm-routing`](../../llm-routing/) does.
- **Pre-pull the EPP image.** The first pull from `registry.k8s.io` was measured at *several
  minutes*; `ctr -n k8s.io images pull` it before anything waits on it or the first check times out.
- **Drop `istioctl`.** Downloading the release tarball to run one install is slow — use the Helm
  charts with the same reduced requests, and confirm the two inference-extension env vars pass
  through as Helm values.
- **Drop NodePort and `NODE_IP` entirely.** The runbook needs them because it is driven from a
  workstation; on Killercoda the terminal is already on the node, so the ClusterIP works and the
  whole indirection disappears.
- **The three scripts become helpers on `PATH`** — `count.sh`, `load.sh` and `queue.sh` in the
  runbook, matching the `llmload` / `llmstats` / `flows` pattern already used here. They read
  metrics through the API server's pod proxy, so no port-forward or extra Pod is needed.
- **Two resource defaults must be overridden** or nothing schedules: istiod requests 2Gi by
  default, and the InferencePool chart's EPP limit is 16Gi. The runbook's values — 100m/256Mi for
  both, 1Gi limit on the EPP — are proven.

## Must resolve before building

- **Node budget.** The runbook needs roughly 1GB beyond a base cluster for 3 simulator replicas,
  the EPP, istiod and the gateway. The simulators are cheap (~37MB each, measured separately);
  istiod is the weight. Confirm on `kubernetes-kubeadm-1node` before assuming the 2-node backend is
  required — the runbook notes single-worker clusters give identical results, because the picker
  chooses Pods, not nodes.
- **A second terminal for `queue.sh`.** Step 3 is far better watched live than sampled. Killercoda
  supports multiple terminal tabs; confirm the `index.json` syntax before designing the step around
  it, and have a sampled fallback if not.
- **Restarting the EPP wipes its in-memory prefix tracking**, and so does restarting the
  simulators. Every step that counts requests needs a fresh baseline afterwards — the checks must
  compare deltas, never cumulative totals.
- **The EPP's Pod label is `inferencepool=<name>-epp`, not `app=`.** Small, but it will silently
  break any helper or check that guesses.

## Why v1.5.0 is pinned

GAIE **split at v1.6**: the endpoint picker, `InferenceObjective` and `InferenceModelRewrite` moved
to `llm-d/llm-d-router`, and the body-based router to `llm-d/llm-d-inference-payload-processor`,
leaving only the `InferencePool` API and the picker protocol in the extension itself.

At v1.5.0 the picker still ships in GAIE's own `inferencepool` chart, so one Helm install produces
both the pool and the EPP. That is why the pin exists, and why bumping it will not be a version
bump — it is a re-architecture. Record it rather than discovering it.

> An earlier version of this spec proposed llm-d Router's standalone mode with no gateway at all.
> That was written from a kind spike that avoided the gateway question rather than answering it.
> The runbook this spec is now built from uses the real topology — an `HTTPRoute` whose `backendRef`
> is an `InferencePool`, served by Istio — and supersedes it.

## Cross-links

- Sequel to [`llm-routing`](../../llm-routing/): that lab establishes that least-request cannot see
  the queue, and its step 3 closing note points here. This lab shows the component that *can* see it
  choosing to ignore it anyway.
- [`envoy-ai-gateway`](../envoy-ai-gateway/) is the third lab on this objective, on the named
  product rather than the mechanism.
- Istio here is **gateway-only, no sidecars**, which is why this spec is not blocked by the
  socket-LB constraint described in `ckne/README.md`. It is the evidence for that distinction.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
