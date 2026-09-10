# IPAM and Pod CIDR Allocation

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Core Infrastructure & CNI (15%) |
| **Exam objective** | Managing IPAM and Pod CIDR Allocation |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Ready |

## What it teaches

The cluster CIDR bounds the per-node `podCIDR`, and the per-node CIDR bounds how many Pods that node can ever run — a ceiling nothing in the scheduler knows about. Exhaust it and Pods schedule successfully, then fail to start with an error that never mentions IP addresses.

## Step outline

1. Find the cluster CIDR and each node's allocated `podCIDR`; work out the real Pod ceiling per node.
2. Scale past that ceiling. Pods are scheduled — the scheduler counts CPU and memory, not addresses — and then fail at sandbox creation.
3. Read the actual error from the CNI, and locate the IPAM state the plugin keeps.
4. Resize the allocation and recover.

## Must resolve before building

- Whether `--node-cidr-mask-size` can be changed on the backend's control plane, or whether the lab must demonstrate exhaustion within the default /24.

## Cross-links

- Pairs with `ckne/01-core-cni/install-and-configure`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
