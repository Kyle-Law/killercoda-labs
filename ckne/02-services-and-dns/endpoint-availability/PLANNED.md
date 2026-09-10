# EndpointSlices Beyond Readiness

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Configuring Pod Endpoint Availability |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready |

## What it teaches

`EndpointSlice` mechanics that readiness alone does not explain: terminating endpoints and graceful shutdown, `publishNotReadyAddresses`, headless Services, and topology-aware routing.

## Step outline

1. Watch an `EndpointSlice` through a rolling update — including the terminating state that exists specifically to avoid dropping in-flight requests.
2. `publishNotReadyAddresses` and why StatefulSet peer discovery needs it.
3. Headless Services: DNS returns Pod addresses directly and no VIP exists at all.
4. Topology-aware routing — traffic preferring same-zone endpoints, and the fallback when they're unavailable.

## Must resolve before building

- Whether the backend has enough nodes/zone labels to demonstrate topology-aware routing meaningfully, or whether that step should be conceptual.

## Cross-links

- Extends `probes/restart-remove-or-wait` (readiness to EndpointSlice) rather than repeating it.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
