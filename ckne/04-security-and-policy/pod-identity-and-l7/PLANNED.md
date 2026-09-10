# Identity-Based and L7 Authorization

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Network Security & Policy (25%) |
| **Exam objective** | Implementing Pod-level Authentication and Authorization |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Verify first |

## What it teaches

Authorization by workload identity rather than IP address, and rules native NetworkPolicy cannot express at all: allow `GET /health`, deny `POST /admin`, on the same port between the same two Pods.

## Step outline

1. Show the limit: native NetworkPolicy is L3/L4, so it cannot distinguish two HTTP paths on one port.
2. Write an L7 rule that allows one method and path while denying another.
3. Observe the enforcement point — a proxy in the datapath, and what that costs.
4. Identity versus IP: why a rule bound to a workload survives a rescheduled Pod and an IP-based one does not.

## Must resolve before building

- Whether the backend's CNI has L7 policy enforcement available (an Envoy component was observed, which is promising but unconfirmed).

## Cross-links

- Extends `netpol/` into what the native API cannot do.
- Depends on `ckne/01-core-cni/install-and-configure`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
