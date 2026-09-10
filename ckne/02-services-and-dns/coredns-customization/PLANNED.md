# Customizing CoreDNS

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Customizing coreDNS for Services |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready |

## What it teaches

The Corefile as a real configuration file rather than a black box: stub domains, conditional forwarding, rewrites, and where cluster DNS ends and upstream begins.

## Step outline

1. Read the running Corefile and map each plugin to an observable behaviour.
2. Add a stub domain forwarding one zone to a different resolver; prove it with a lookup that changes answer.
3. Add a `rewrite` so an internal name resolves to a Service, and understand the ordering constraint that makes plugin position matter.
4. Break it deliberately — a malformed Corefile — and see how CoreDNS reports it and what happens to cluster DNS meanwhile.

## Must resolve before building

- That the CoreDNS ConfigMap can be edited and reloaded on the backend within a lab's time budget.

## Cross-links

- `troubleshooting/services-dns` covers DNS *failures*; this covers configuring it.
- Recommended second build in the roadmap.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
