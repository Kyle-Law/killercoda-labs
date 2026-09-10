# Auditing Traffic with Flow Logs

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Observability (15%) |
| **Exam objective** | Auditing Traffic with Logs |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Verify first |

## What it teaches

Seeing traffic actually flow, and seeing a drop attributed to the specific policy that caused it — which turns every NetworkPolicy lab from guesswork into observation.

## Step outline

1. Observe live flows between workloads and read the identity labels attached to each end.
2. Apply a policy that blocks something; find the drop and the reason.
3. Filter to one workload and answer 'what is talking to this, and what is being refused?'
4. Use flow data to derive an allow-list from real traffic — the safe way to introduce default-deny.

## Must resolve before building

- Whether Hubble (or equivalent flow logging) is enabled on the backend, or can be enabled by `ckne/01-core-cni/install-and-configure`.

## Cross-links

- Makes `netpol/allow-only-and-default-deny` and `netpol/egress-and-the-dns-trap` debuggable.
- The observe-then-enforce workflow was scoped earlier as `netpol/staging-a-default-deny-safely`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
