# CKNE — Certified Kubernetes Networking Engineer

Lab roadmap for the CKNE exam, organised by the five exam domains.

This folder is a **curriculum map plus a home for networking labs that have no existing topic folder**.
It deliberately does not duplicate labs that already live elsewhere — the repo's organising principle is
topic-first, so a lab is written once and referenced from every curriculum that needs it. Where a domain is
already served by an existing lab, this map links to it rather than copying it.

## Domain weights and current coverage

| Domain | Weight | Coverage today |
|---|---|---|
| [Core Infrastructure & CNI](01-core-cni/) | 15% | None |
| [Service Networking & DNS](02-services-and-dns/) | 25% | Partial — exists but under-weighted |
| [Advanced Traffic Management](03-traffic-management/) | 20% | None |
| [Network Security & Policy](04-security-and-policy/) | 25% | Partial — strongest area |
| [Observability](05-observability/) | 15% | Partial |

Domain order is **not** build order. See [Build order](#build-order).

## Resolve this first

Roughly a third of these labs depend on which CNI features the Killercoda `kubernetes-kubeadm-*` backend has
enabled — flow logs, kube-proxy replacement, transparent encryption, egress gateway, L7 policy. A
`cilium-envoy` Service was observed in a live session, so a policy-enforcing CNI is present, but the feature
flags are unconfirmed.

Rather than spending a session investigating: **installing and configuring a CNI is itself Domain 1 content.**
[`01-core-cni/install-and-configure`](01-core-cni/install-and-configure/PLANNED.md) satisfies an exam objective
*and* answers the feasibility question for Domains 3, 4 and 5 in the same lab. Build it first.

## Build order

Chosen by exam weight × current gap, not by domain number.

1. **[`01-core-cni/install-and-configure`](01-core-cni/install-and-configure/PLANNED.md)** — the unblocker, above.
2. **[`01-core-cni/packet-path-with-linux-tools`](01-core-cni/packet-path-with-linux-tools/PLANNED.md)** — every
   troubleshooting objective in the exam rests on being able to follow a packet. Nothing in the repo teaches it.
3. **[`02-services-and-dns/coredns-customization`](02-services-and-dns/coredns-customization/PLANNED.md)** —
   explicit objective in the heaviest domain, zero coverage. The existing DNS lab only breaks DNS; none configure it.
4. **[`02-services-and-dns/httproute-in-depth`](02-services-and-dns/httproute-in-depth/PLANNED.md)** —
   `networking/ingress-and-gateway-api` is two steps, far too thin for a 25% domain that names Gateway API directly.
5. **The four `Ready` security labs** — an area with an established, working pattern to copy.
6. **Defer everything marked `Verify first`** until step 1 has established which features exist.
7. **Treat cross-cluster as out of scope** unless nested clusters prove workable.

## Labs that live outside this folder

These serve CKNE domains but belong to topic folders, per the no-duplication principle:

| Lab | Domain | Status |
|---|---|---|
| [`netpol/allow-only-and-default-deny`](../netpol/allow-only-and-default-deny/) | Security & Policy | Built |
| [`netpol/egress-and-the-dns-trap`](../netpol/egress-and-the-dns-trap/) | Security & Policy | Built |
| `netpol/selectors-that-fail-open` | Security & Policy | Planned — AND vs OR selector semantics, the version that fails *open* |
| `netpol/the-policy-you-didnt-write` | Security & Policy | Planned — additive union as a security hole |
| `netpol/blind-spots` | Security & Policy | Planned — `hostNetwork` bypass, Service-path enforcement |
| [`networking/ingress-and-gateway-api`](../networking/ingress-and-gateway-api/) | Services & DNS | Built — deepened by `02-services-and-dns/httproute-in-depth` |
| [`networking/multi-port-services`](../networking/multi-port-services/) | Services & DNS | Built |
| [`troubleshooting/services-dns`](../troubleshooting/services-dns/) | Services & DNS | Built — failures only, not configuration |
| [`probes/restart-remove-or-wait`](../probes/restart-remove-or-wait/) | Services & DNS | Built — readiness → EndpointSlice |
| [`observability/prometheus-operator`](../observability/prometheus-operator/) | Observability | Built |
| [`ai-workloads/inference-sim`](../ai-workloads/inference-sim/) | Traffic Management | Built — reused by `03-traffic-management/llm-routing` |

## Conventions

Each unbuilt lab is a directory containing a single `PLANNED.md` design spec. There is deliberately no stub
`index.json` — Killercoda only picks up directories that have one, so nothing here can be mistaken for, or
published as, a working lab until it is genuinely finished.

When building one, follow the repo standard: `index.json`, `intro.md`, `init/background.sh` + `init/foreground.sh`,
`stepN/text.md` + `stepN/verify.sh`, `finish.md`. Every claim in the lab text must be reproduced on a live cluster
before it is written down, and any lab asserting traffic is *blocked* must fail loudly on a non-enforcing CNI
rather than passing vacuously.

> Planned from a supplied domain outline, not the published CNCF curriculum. Reconcile the objectives and
> weightings against the official document before treating this as authoritative.
