# Cross-Cluster Service Discovery

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Implementing Cross Cluster Service Discovery and Load Balancing |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Blocked — needs two clusters |

## What it teaches

Global Services spanning clusters, failover between them, and the fact that network policy is *not* distributed along with them — a documented gap that surprises people.

## Step outline

1. Connect two clusters and expose a Service as global.
2. Observe load balancing across both clusters' endpoints.
3. Fail one cluster's backend and watch traffic shift.
4. Demonstrate the policy gap: a policy applied in one cluster does not protect the other.

## Must resolve before building

- Whether two clusters are possible at all on Killercoda — nested k3d/kind, or a second kubeadm control plane on the worker node. Unproven.
- Treat as out of scope until proven, consistent with the same call made for Kustomize multi-cluster.

## Cross-links

- _None yet._

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
