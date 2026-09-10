# TLS for Gateway API Listeners

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Network Security & Policy (25%) |
| **Exam objective** | Managing TLS Certificates for Gateway API |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready |

## What it teaches

Terminating TLS at the Gateway: where the certificate lives, how a listener references it, SNI across multiple hostnames, and the difference between terminating and passing through.

## Step outline

1. An HTTPS listener referencing a certificate Secret; confirm the served certificate is the one intended.
2. Two hostnames, two certificates, one listener — SNI selecting between them.
3. Issue certificates automatically rather than by hand, and watch renewal replace the Secret.
4. Passthrough instead of termination, and what the Gateway can no longer do once it cannot read the traffic.

## Must resolve before building

- That cert-manager (or equivalent) installs on the backend within a reasonable init budget.
- Which Gateway controller is available — TLS support varies by implementation.

## Cross-links

- Requires `ckne/02-services-and-dns/httproute-in-depth` first.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
