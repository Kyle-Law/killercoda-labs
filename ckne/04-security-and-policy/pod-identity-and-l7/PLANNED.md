# Identity-Based and L7 Authorization

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Network Security & Policy (25%) |
| **Exam objective** | Implementing Pod-level Authentication and Authorization |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Ready** — L7 enforcement confirmed on the backend's CNI |

## What it teaches

Authorization by workload identity rather than IP address, and rules native NetworkPolicy cannot express at all: allow `GET /health`, deny `POST /admin`, on the same port between the same two Pods.

## Step outline

1. Show the limit: native NetworkPolicy is L3/L4, so it cannot distinguish two HTTP paths on one port.
2. Write an L7 rule that allows one method and path while denying another.
3. Observe the enforcement point — a proxy in the datapath, and what that costs.
4. Identity versus IP: why a rule bound to a workload survives a rescheduled Pod and an IP-based one does not.

## Resolved

L7 policy **works**, verified against a cluster reproducing the backend's exact Cilium configuration
(`kubeProxyReplacement=true`, `cilium-envoy` as its own DaemonSet, no `hubble-relay`):

- `CiliumNetworkPolicy` `cilium.io/v2` is present, and `toPorts.rules.http` is enforced.
- With a rule allowing only `GET /hostname`: `GET /hostname` → **200**, `GET /` → **403**,
  `POST /hostname` → **403**. Same port, same two Pods, different verdict per method and path —
  exactly what the objective asks for and what native NetworkPolicy cannot express.
- The refusal is a **403, not a timeout**: the proxy terminates the request and answers. That is the
  distinguishing signature of L7 enforcement versus an L3/L4 drop, which yields `000`/no response.
- `hubble observe --protocol http` attributes it precisely:
  `http-request DROPPED (HTTP/1.1 POST http://api/hostname)` followed by the proxy's own
  `http-response FORWARDED (HTTP/1.1 403)`.

## Cross-links

- Extends `netpol/` into what the native API cannot do.
- Depends on `ckne/01-core-cni/install-and-configure`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
