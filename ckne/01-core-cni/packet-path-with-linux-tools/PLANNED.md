# Following a Packet with ip, tcpdump and iptables

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Core Infrastructure & CNI (15%) |
| **Exam objective** | Using Linux Tools (iptables, ip, tcpdump) for Packet-level Issues |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready |

## What it teaches

A Pod's network namespace, the veth pair that connects it to the host, and the NAT that rewrites a Service address into a Pod address. Learners capture one real request at each hop instead of reasoning about it.

## Step outline

1. From inside a Pod, find its interface index, then find the matching veth peer on the host — the link most people never realise is there.
2. `tcpdump` on that veth while making one request. Watch the packet leave.
3. Make the same request through a Service and find the DNAT rule that rewrote the destination.
4. Capture on both ends of one connection and account for every address translation between them.

## Must resolve before building

- That `tcpdump`, `nsenter` and `iptables` are present on the backend node, and that `crictl`/`nsenter` can enter a Pod netns.

## Cross-links

- Foundation for `ckne/01-core-cni/pod-connectivity-triage` and `ckne/02-services-and-dns/kube-proxy-and-the-datapath`.
- Recommended first build in the roadmap.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
