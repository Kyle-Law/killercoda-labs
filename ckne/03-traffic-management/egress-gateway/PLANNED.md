# A Fixed Source IP for Cluster Exit Traffic

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Configuring Egress Gateways for Cluster Exit Traffic |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Verify first |

## What it teaches

External systems allowlist addresses, but Pod IPs are ephemeral and node IPs multiply. An egress gateway forces selected traffic out through one predictable address.

## Step outline

1. Show the problem: the same workload exits via different addresses depending on where it is scheduled.
2. Configure an egress gateway policy selecting that workload.
3. Prove the SNAT — observe the source address an external listener actually sees.
4. Scope it correctly: only the selected traffic should be affected, and the blast radius of getting the selector wrong.

## Must resolve before building

- Whether the CNI's egress gateway feature can be enabled on the backend, and whether an external endpoint is reachable to observe the source address.

## Cross-links

- Depends on `ckne/01-core-cni/install-and-configure`.
- Selector-scoping mistakes mirror `netpol/` — cross-link.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
