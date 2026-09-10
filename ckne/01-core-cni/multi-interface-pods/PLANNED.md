# Pods with More Than One Interface

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Core Infrastructure & CNI (15%) |
| **Exam objective** | Configuring Multi-interface Pods |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Verify first |

## What it teaches

A second network attachment via Multus: what `NetworkAttachmentDefinition` produces inside the Pod, and which interface the default route actually uses — the part that surprises people.

## Step outline

1. Install Multus as the meta-plugin and see how it chains to the existing CNI.
2. Define a second network and attach it to a Pod via annotation.
3. Inspect the Pod's interfaces and routing table; identify which traffic leaves by which path.
4. Break it usefully: traffic that was expected on the secondary interface leaving via the primary instead.

## Must resolve before building

- That Multus installs cleanly on the backend and chains to the preinstalled CNI without breaking existing Pod networking.
- Whether a second network can be backed by something available on a single-node/2-node Killercoda host (macvlan/bridge).

## Cross-links

- _None yet._

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
