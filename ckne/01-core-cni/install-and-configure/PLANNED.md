# Installing and Configuring a CNI

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Core Infrastructure & CNI (15%) |
| **Exam objective** | Installing and Configuring CNI Plugins |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Ready |

## What it teaches

Pods sit `Pending` with no CNI installed, and the kubelet says why only if you know where to look. Install a CNI, watch Pods get addresses, then read what was actually written to disk: `/etc/cni/net.d`, the plugin binaries in `/opt/cni/bin`, and the config the kubelet hands to them.

## Step outline

1. Observe the failure: Pods `Pending`/`ContainerCreating`, `NetworkNotReady` on the node, and the kubelet error naming the missing CNI config.
2. Install the CNI. Watch the node flip to `Ready` and Pods get IPs from the pod CIDR.
3. Read what changed on disk — the CNI conflist, the plugin chain, and which fields the kubelet actually consumes.
4. Enable the optional features later labs depend on (Hubble, kube-proxy replacement) and confirm each is genuinely on, not just configured.

## Must resolve before building

- Whether the backend ships a preinstalled CNI that must be removed first, or a node that can be brought up without one.
- Which Cilium/Calico feature flags the backend permits — this lab is the designated unblocker for Domains 3, 4 and 5.

## Cross-links

- Unblocks: `ckne/03-*`, `ckne/04-*` encryption + L7, `ckne/05-*` flow logs.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
