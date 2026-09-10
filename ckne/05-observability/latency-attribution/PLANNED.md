# Where the Latency Actually Is

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Observability (15%) |
| **Exam objective** | Troubleshooting End to End Network Performance with Tracing |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Ready |

## What it teaches

Splitting 'the network is slow' into DNS time, connection setup, and application time — so the claim becomes a measurement instead of an accusation.

## Step outline

1. Measure a request broken into phases; establish which phase dominates.
2. Inject slowness in DNS specifically and watch which phase moves.
3. Inject application slowness instead — same total, different attribution.
4. Cross-node versus same-node latency, and what the difference tells you.

## Must resolve before building

- That latency can be injected reproducibly on the backend without destabilising it.

## Cross-links

- `ai-workloads/inference-latency` covers latency measurement for inference specifically.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
