# CKNE — Certified Kubernetes Networking Engineer

Lab roadmap for the CKNE exam, organised by the five exam domains.

**Built CKNE labs live here, one directory each**, alongside `PLANNED.md` design specs for the ones still to
come. It deliberately does not duplicate labs that already exist elsewhere in the repo — where a domain is
already served by, say, a `netpol/` lab, this map links to it rather than copying it.

Built labs sit **directly under `ckne/`**, not inside the numbered domain folders. Killercoda appears to index
scenarios exactly two levels deep — `<folder>/<scenario>/index.json` — so `ckne/coredns-customization/`
publishes and `ckne/02-services-and-dns/coredns-customization/` does not. The domain folders hold specs only,
where depth doesn't matter because there is no `index.json` to find.

| Built | Domain |
|---|---|
| [`cni-install-and-configure`](cni-install-and-configure/) | Core Infrastructure & CNI |
| [`packet-path-with-linux-tools`](packet-path-with-linux-tools/) | Core Infrastructure & CNI |
| [`coredns-customization`](coredns-customization/) | Service Networking & DNS |

## Domain weights and current coverage

| Domain | Weight | Coverage today |
|---|---|---|
| [Core Infrastructure & CNI](01-core-cni/) | 15% | Partial — 2 of 5 built |
| [Service Networking & DNS](02-services-and-dns/) | 25% | Partial — CoreDNS built, rest under-weighted |
| [Advanced Traffic Management](03-traffic-management/) | 20% | None |
| [Network Security & Policy](04-security-and-policy/) | 25% | Partial — strongest area |
| [Observability](05-observability/) | 15% | Partial |

Domain order is **not** build order. See [Build order](#build-order).

## Resolved: don't inherit the backend's CNI, replace it

Roughly a third of these labs depend on which CNI features are available — flow logs, kube-proxy replacement,
transparent encryption, egress gateway, L7 policy. The original plan was to discover what the Killercoda
`kubernetes-kubeadm-*` backend happens to ship with and work within it.

[`cni-install-and-configure`](cni-install-and-configure/) makes that question moot. Its
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

1. ~~**`01-core-cni/install-and-configure`**~~ — **built** as
   [`cni-install-and-configure`](cni-install-and-configure/), and the unblocker described above.
2. ~~**`01-core-cni/packet-path-with-linux-tools`**~~ — **built** as
   [`packet-path-with-linux-tools`](packet-path-with-linux-tools/): find a Pod's veth by kernel `ifindex`
   (not by name — CNI-agnostic), capture one request raw on it, then capture both ends of a Service-routed
   connection at once and prove by matching TCP sequence numbers that only the destination is translated.
3. ~~**`02-services-and-dns/coredns-customization`**~~ — **built** as
   [`coredns-customization`](coredns-customization/): stub domains, rewrites, plugin order, and the broken
   Corefile that takes nothing down until a Pod restarts.
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

**A finished lab moves out of its domain folder to sit directly under `ckne/`.** Killercoda appears to index
scenarios exactly two levels deep, `<folder>/<scenario>/index.json`, so a lab left inside a numbered domain
folder is three levels down and never published. Every scenario in every Killercoda repo that could be
inspected — the official `killercoda/scenario-examples`, `chadmcrowell/killercoda-scenarios` (318 scenarios),
`het-tanis/prolug-labs` (86) — sits at depth 1 or 2, and none at depth 3.

> That is inference from consistent evidence, not a documented rule: killercoda.com renders client-side, so
> the creator docs could not be read directly. `archive/learning-linux/linux-files-introduction` is this
> repo's other depth-3 scenario — if it is also missing from the profile, the rule is confirmed.

When building one, follow the repo standard: `index.json`, `intro.md`, `init/background.sh` + `init/foreground.sh`,
`stepN/text.md` + `stepN/verify.sh`, `finish.md`. Every claim in the lab text must be reproduced on a live cluster
before it is written down, and any lab asserting traffic is *blocked* must fail loudly on a non-enforcing CNI
rather than passing vacuously.

> Planned from a supplied domain outline, not the published CNCF curriculum. Reconcile the objectives and
> weightings against the official document before treating this as authoritative.
