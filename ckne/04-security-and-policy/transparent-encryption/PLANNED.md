# Node-to-Node Encryption

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Network Security & Policy (25%) |
| **Exam objective** | Implementing Node and Pod Level Encryption |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Verify first |

## What it teaches

Encrypting Pod traffic as it crosses between nodes, and — critically — proving it rather than trusting the setting, by capturing on the wire before and after.

## Step outline

1. Capture inter-node Pod traffic unencrypted and read the payload off the wire.
2. Enable transparent encryption.
3. Capture again and confirm the payload is no longer readable.
4. Establish what is *not* covered — same-node traffic, and traffic leaving the cluster.

## Must resolve before building

- Whether WireGuard/IPsec can be enabled on the backend's CNI, and whether the kernel supports it.
- That inter-node capture is possible on a 2-node Killercoda backend.

## Cross-links

- Depends on `ckne/01-core-cni/install-and-configure`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
