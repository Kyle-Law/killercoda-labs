# Routing Inference Traffic

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Optimizing LLM Traffic |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready |

## What it teaches

Why inference workloads break assumptions built into ordinary load balancing: responses stream for minutes, request cost varies by orders of magnitude, and round-robin sends work to the busiest replica as readily as the idlest.

## Step outline

1. Stream a long completion through a proxy with a default idle timeout and watch it get cut off mid-response.
2. Compare round-robin against a queue-depth signal when replica load is deliberately uneven.
3. Route by model name to distinct backends.
4. Establish which metric actually belongs on the autoscaler — queue depth, not CPU.

## Must resolve before building

- Nothing blocking — `ai-workloads/inference-sim` already runs a GPU-free vLLM simulator with real vLLM metric names.

## Cross-links

- Reuses the simulator from `ai-workloads/inference-sim`.
- `ai-workloads/inference-latency` already covers latency measurement.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
