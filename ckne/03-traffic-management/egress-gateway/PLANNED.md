# A Fixed Source IP for Cluster Exit Traffic

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Configuring Egress Gateways for Cluster Exit Traffic |
| **Mapped tech** | Istio (Egress Gateway) + Cilium (Egress Gateway feature) |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Verify first |

## What it teaches

External systems allowlist addresses, but Pod IPs are ephemeral and node IPs multiply. An egress gateway forces selected traffic out through one predictable address.

## Step outline

1. Show the problem: the same workload exits via different addresses depending on where it is scheduled.
2. Configure an egress gateway policy selecting that workload.
3. Prove the SNAT — observe the source address an external listener actually sees.
4. Scope it correctly: only the selected traffic should be affected, and the blast radius of getting the selector wrong.

## Two technologies, one objective

The curriculum maps this objective to **both** Cilium's egress gateway and Istio's, and they are
not the same mechanism wearing two names:

- **Cilium** SNATs at the datapath. Traffic leaves through a chosen node's address whether the
  workload knows or not, and nothing in the Pod changes.
- **Istio** routes through an egress *gateway Pod* — a real proxy hop, which can therefore
  terminate TLS, apply policy and log the request, and which the workload's sidecar has to be
  told to use.

The difference that matters: Istio's can be **bypassed**. A workload that talks directly to an
external address, or one with no sidecar, simply does not go through it — so as a security
control it needs a separate mechanism to force the traffic in. Cilium's is in the datapath and
has no such hole, but it also cannot see or decide anything about the request it is SNATing.

The lab should build one and then state the other's trade-off honestly, rather than claiming
either covers the objective alone.

## Must resolve before building

- Whether the CNI's egress gateway feature can be enabled on the backend, and whether an external endpoint is reachable to observe the source address.
- **Which of the two to build.** Cilium's is the cheaper build — the CNI is already there — and
  avoids the Istio-on-Cilium prerequisite recorded in `ckne/README.md`. Istio's teaches the
  richer failure (a control that can be walked around). Building Cilium's with an honest section
  on Istio's bypass is probably the right trade; decide before writing step 2.

## Cross-links

- Depends on `ckne/01-core-cni/install-and-configure`.
- Selector-scoping mistakes mirror `netpol/` — cross-link.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
