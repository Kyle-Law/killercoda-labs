# Kubernetes inference: a hypothetical exam

There is no performance-based certification for running inference on Kubernetes yet, not one this repo
knows of. This folder assumes there is one and drafts its blueprint: what a CKA-style terminal exam could
grade on a cluster with **no GPUs**, anchored on what the CNCF Kubernetes AI Conformance program already
treats as baseline (DRA, Gateway API Inference Extension, autoscaling on custom metrics, gang
scheduling, accelerator metrics).

Like [`ckne/`](../ckne/README.md), it maps the domains onto labs and **does not duplicate them**. Most of
this exam is already served by `ai-workloads/`, `ckne/`, `probes/` and `troubleshooting/`; this folder
holds specs only for the gaps.

## Status

**Nothing built here yet: four specs, the rest ideas.** A spec has deliberately no `index.json`, so
Killercoda cannot publish it by accident.

| Spec | Domain | Status | Finding |
|---|---|---|---|
| [`draining-model-servers`](draining-model-servers/) | Model server lifecycle | **Ready**, all observed | A rollout cuts a streaming answer mid-sentence, and raising `terminationGracePeriodSeconds` does not fix it: the server has its own 30s drain clock. An `exec` preStop in a shell-less image fails with only an event |
| [`autoscale-on-queue-depth`](autoscale-on-queue-depth/) | Autoscaling | Steps 1-3 **ready**, step 4 to resolve | The metric is `vllm:num_requests_waiting` with the colon; the underscore form is NotFound. And `AverageValue` hides one replica with eight queued |
| [`model-weights-as-images`](model-weights-as-images/) | Model delivery | Steps 1-3 **ready**, step 4 to resolve | A wrong weights reference reports `ImagePullBackOff` on a container whose own image is fine. `subPath` into an image volume works for a directory and fails for a file |
| [`inference-capstone`](inference-capstone/) | Troubleshooting | Assembly, ordering **unverified** | Four faults on one model server, each from the specs above; the weights fault hides the probe fault |

**Observed on a live cluster** (kind, Kubernetes v1.37.0, containerd 2.3.4, `llm-d-inference-sim`
v0.11.2, prometheus-adapter chart 5.4.0): every table of results in those specs. Nothing in the ideas
list below has been run.

## Domains, weights and coverage

The weights are a guess, ordered by how likely a domain is to be examined and how gradable it is from a
terminal.

| Domain | Weight | Already served by | Gap |
|---|---|---|---|
| Troubleshooting inference workloads | 25% | [`troubleshooting/pod-failures`](../troubleshooting/pod-failures/) (OOMKilled, readiness), [`probes/restart-remove-or-wait`](../probes/restart-remove-or-wait/) (slow start), [`ckne/inference-pool-by-hand`](../ckne/inference-pool-by-hand/) (every object green, every request failing) | [`inference-capstone`](inference-capstone/) |
| Accelerators and scheduling | 20% | [`ai-workloads/gpu-scheduling`](../ai-workloads/gpu-scheduling/), [`ai-workloads/dra-devices`](../ai-workloads/dra-devices/), [`ai-workloads/gang-scheduling`](../ai-workloads/gang-scheduling/), [`workloads/scheduling-constraints`](../workloads/scheduling-constraints/) | The failure side of DRA (see ideas) |
| Inference routing | 20% | [`ckne/llm-routing`](../ckne/llm-routing/), [`ckne/inference-gateway`](../ckne/inference-gateway/), [`ckne/inference-pool-by-hand`](../ckne/inference-pool-by-hand/), [`ckne/httproute-in-depth`](../ckne/httproute-in-depth/) | Covered. Criticality and LoRA routing are ideas |
| Model server lifecycle and delivery | 15% | [`ai-workloads/inference-sim`](../ai-workloads/inference-sim/) (probes, failure injection), [`probes/readiness-and-safe-rollouts`](../probes/readiness-and-safe-rollouts/) | [`draining-model-servers`](draining-model-servers/), [`model-weights-as-images`](model-weights-as-images/) |
| Autoscaling | 10% | [`ckne/llm-routing`](../ckne/llm-routing/) step 4 names the metric but does not wire it | [`autoscale-on-queue-depth`](autoscale-on-queue-depth/) |
| Observability | 10% | [`ai-workloads/inference-observability`](../ai-workloads/inference-observability/), [`ai-workloads/inference-latency`](../ai-workloads/inference-latency/), [`observability/prometheus-operator`](../observability/prometheus-operator/) | Covered |

## Ideas, by domain

**Accelerators and scheduling**

- **The claim that cannot be satisfied.** `dra-devices` is the happy path. A `ResourceClaimTemplate`
  whose CEL selector matches no device leaves the Pod `Pending`, and the reason is on the claim, not the
  Pod. *Verify first:* where the message actually lands on v1.37.
- **Preemption between serving tiers.** Covered as mechanism by `gpu-scheduling` step 4 and the
  `scheduling/preemption-in-depth` spec (on the `spec/scheduling` branch); an inference framing would
  add nothing new. Cross-link rather than build.
- **Multi-host serving with LeaderWorkerSet.** One model sharded across a leader and workers, restarted
  as a group when one worker dies. *Verify first:* the install footprint on a one-node backend.

**Inference routing**

- **Criticality.** `InferenceObjective` priorities, and which requests the picker sheds first when the
  pool saturates. *Verify first:* the API version the installed GAIE release serves.
- **LoRA adapters.** One base model, several adapters, and routing that prefers a replica with the
  adapter already loaded. The simulator advertises `vllm:lora_requests_info`.

**Model server lifecycle and delivery**

- **Model weights on a shared PVC.** `ReadOnlyMany`, and the first Pod that writes the cache while the
  others read a half-written file. *Verify first:* whether the backend's storage class supports it.

**Autoscaling**

- **Scale to zero.** On v1.37 an HPA status already carries a `ScaledToZero` condition
  (`NotScaledToZero` was observed); whether `minReplicas: 0` is accepted without a feature gate was not
  tried. KEDA is the established route.

**Troubleshooting**

- **A readiness probe on the wrong path.** `/ready` returns 404 from the simulator; the endpoint is
  `/health/ready`. Observed by accident while writing these specs. Used in the capstone rather than
  built alone, since `ai-workloads/inference-sim` already teaches the two endpoints.

**Out of scope** for a terminal exam on a GPU-less cluster: GPU Operator and driver internals,
inference engine tuning (quantisation, batching, KV cache sizing), multi-cluster serving, training.

## Where to start

`draining-model-servers` is ready to build as written. `autoscale-on-queue-depth` next; its step 4
depends on a measurement the `cka/hpa-without-requests` spec also needs, so take that once for both.
`model-weights-as-images` needs the backend's containerd version checked before anything else. The
capstone last, because it reuses faults the other three prove.

## Conventions

Same as everywhere else in this repo. See [`ckne/README.md`](../ckne/README.md) for the ones that bite:

- **Scenarios index exactly two levels deep.** A finished lab is `inference-exam/<scenario>/index.json`.
- **Every check must say what it wanted.** Each `verify.sh` writes its reason to `/root/.check`, and each
  init installs the `why` helper that prints it.
- **Every claim reproduced on a live cluster before it is written down.**
