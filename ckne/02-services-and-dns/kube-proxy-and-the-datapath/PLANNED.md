# kube-proxy, IPVS and the eBPF Replacement

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Understanding kube-proxy and CNI Alternatives |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Verify first |

## What it teaches

What implements a Service, concretely. Read the iptables chains kube-proxy writes for one Service, compare the IPVS equivalent, then remove kube-proxy entirely and watch the same Service keep working with no chains at all.

## Step outline

1. Trace one Service through the iptables chains kube-proxy generates; find the DNAT and the per-endpoint probability rules.
2. Switch to IPVS mode and compare — same behaviour, different data structure, different scaling characteristics.
3. Enable the eBPF kube-proxy replacement; confirm the chains are gone and the Service still resolves.
4. Compare rule count growth as Services scale, and reason about why the datapath choice matters at size.

## Must resolve before building

- Whether kube-proxy mode can be switched on the backend, and whether the CNI's kube-proxy replacement can be enabled without rebuilding the cluster.

## Cross-links

- Depends on `ckne/01-core-cni/install-and-configure` for feature enablement.
- Builds on `packet-path-with-linux-tools`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
