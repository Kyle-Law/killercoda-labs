# LoadBalancer Without a Cloud

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Implementing Routing to Expose Networks |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Verify first |

## What it teaches

What actually assigns an external IP when no cloud controller exists: an address pool, an allocator, and a mechanism for advertising the address to the surrounding network.

## Step outline

1. A `LoadBalancer` Service stuck in `Pending` forever, and why.
2. Install an allocator and define an address pool; watch the assignment happen.
3. L2 advertisement — which node answers for the address, and what happens when it goes away.
4. Contrast with BGP advertisement conceptually, and when L2 stops being sufficient.

## Must resolve before building

- Whether L2 advertisement is observable inside the Killercoda network, or whether the lab can only demonstrate allocation and not reachability.

## Cross-links

- _None yet._

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
