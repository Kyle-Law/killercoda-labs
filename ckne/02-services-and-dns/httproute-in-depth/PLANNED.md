# Gateway API: Listeners, Matching and Splitting

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Managing Traffic with the Gateway API (Gateway, HTTPRoutes) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready |

## What it teaches

The routing Ingress genuinely cannot express: multiple listeners, hostname and header matching, weighted traffic splitting, and the role/namespace separation between `Gateway` and `HTTPRoute`.

## Step outline

1. A `Gateway` with more than one listener, and `HTTPRoute`s attaching to a specific one.
2. Match on path, then header, then method — and observe precedence when two rules both match.
3. Weighted split across two backends; measure the actual distribution rather than trusting the weight.
4. Attach a route from another namespace and hit the `ReferenceGrant` requirement.

## Must resolve before building

- Which Gateway API CRD version and controller implementation the backend supports — the existing `networking/ingress-and-gateway-api` lab already installs some of this.

## Cross-links

- Deepens `networking/ingress-and-gateway-api` (currently two steps).
- Recommended third build in the roadmap.
- Prerequisite for `ckne/04-security-and-policy/gateway-tls`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
