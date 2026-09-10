# CKNE — Certified Kubernetes Networking Engineer

Lab roadmap for the CKNE exam, organised by the five exam domains.

This folder is a **curriculum map plus a home for networking labs that have no existing topic folder**.
It deliberately does not duplicate labs that already live elsewhere — the repo's organising principle is
topic-first, so a lab is written once and referenced from every curriculum that needs it. Where a domain is
already served by an existing lab, this map links to it rather than copying it.

## Domain weights and current coverage

| Domain | Weight | Coverage today |
|---|---|---|
| [Core Infrastructure & CNI](01-core-cni/) | 15% | Partial — install/configure built |
| [Service Networking & DNS](02-services-and-dns/) | 25% | Partial — exists but under-weighted |
| [Advanced Traffic Management](03-traffic-management/) | 20% | None |
| [Network Security & Policy](04-security-and-policy/) | 25% | Partial — strongest area |
| [Observability](05-observability/) | 15% | Partial |

Domain order is **not** build order. See [Build order](#build-order).

## Resolved: don't inherit the backend's CNI, replace it

Roughly a third of these labs depend on which CNI features are available — flow logs, kube-proxy replacement,
transparent encryption, egress gateway, L7 policy. The original plan was to discover what the Killercoda
`kubernetes-kubeadm-*` backend happens to ship with and work within it.

[`cni/install-and-configure`](../cni/install-and-configure/) makes that question moot. Its
`init/background.sh` removes whatever CNI the backend arrived with — identifying it generically, by the one
thing only a CNI does: hostPath-mounting `/etc/cni/net.d` — and the lab then installs Cilium 1.19.7 at a
pinned version with `kubeProxyReplacement=true` and Hubble enabled.

**Any lab needing a specific CNI feature can reuse that init script rather than hoping.** The removal is
vendor-agnostic (it resolves the owning Helm release from Helm's own annotations, falling back to deleting the
DaemonSet and its operator), so it does not depend on the backend keeping the CNI it has today.

> Verified end to end against a kubeadm cluster — `kind` v1.37, containerd, systemd — which is the same shape
> as the Killercoda backend but not the backend itself. The parts that are environment-sensitive are the CNI
> removal and the `helm`/`ctr` availability at the top of the init script. Run it once on Killercoda before
> building anything else on top of it.

## Build order

Chosen by exam weight × current gap, not by domain number.

1. ~~**`01-core-cni/install-and-configure`**~~ — **built**, as
   [`cni/install-and-configure`](../cni/install-and-configure/), and the unblocker described above.
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
| [`cni/install-and-configure`](../cni/install-and-configure/) | Core Infrastructure & CNI | Built — the unblocker above |
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

**A finished lab does not stay in this folder.** It moves to a topic folder at the top level, and this map
links to it — the same rule the rest of the repo follows, and the reason a lab can serve CKA, CKS and CKNE at
once. There is also a hard constraint behind it: **Killercoda appears to index scenarios exactly two levels
deep**, `<topic>/<scenario>/index.json`. The domain folders here add a third level, so a built lab left in
place is never published. Every scenario in every Killercoda repo that could be inspected — the official
`killercoda/scenario-examples`, `chadmcrowell/killercoda-scenarios` (318 scenarios), `het-tanis/prolug-labs`
(86) — sits at depth 1 or 2, and none at depth 3.

> That is inference from consistent evidence, not a documented rule: killercoda.com renders client-side, so
> the creator docs could not be read directly. `archive/learning-linux/linux-files-introduction` is this
> repo's other depth-3 scenario — if it is also missing from the profile, the rule is confirmed.

When building one, follow the repo standard: `index.json`, `intro.md`, `init/background.sh` + `init/foreground.sh`,
`stepN/text.md` + `stepN/verify.sh`, `finish.md`. Every claim in the lab text must be reproduced on a live cluster
before it is written down, and any lab asserting traffic is *blocked* must fail loudly on a non-enforcing CNI
rather than passing vacuously.

> Planned from a supplied domain outline, not the published CNCF curriculum. Reconcile the objectives and
> weightings against the official document before treating this as authoritative.
