# externalTrafficPolicy and the Client IP

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Troubleshooting Service Network Traffic |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Ready |

## What it teaches

`Cluster` policy adds a second hop that SNATs the client address; `Local` preserves it but changes load distribution and health-check behaviour. The trade-off is real and both sides cost something.

## Step outline

1. With `Cluster` policy, observe the source address the backend Pod actually sees — not the client's.
2. Switch to `Local`; the real client IP appears, but traffic now only reaches Pods on the receiving node.
3. See the consequence: uneven distribution, and nodes with no local endpoint refusing the traffic.
4. Reason about which to choose when logs, policy or geolocation depend on the source IP.

## Must resolve before building

- That a 2-node backend can demonstrate the node-local restriction convincingly.

## Cross-links

- Complements `troubleshooting/services-dns`.
- Relevant to `netpol/` — policy matching on a SNAT'd address fails confusingly.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
