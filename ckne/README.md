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
| [`httproute-in-depth`](httproute-in-depth/) | Service Networking & DNS |
| [`gateway-tls`](gateway-tls/) | Network Security & Policy |
| [`packet-fault-triage`](packet-fault-triage/) | Core Infrastructure & CNI |
| [`llm-routing`](llm-routing/) | Advanced Traffic Management |
| [`flow-logs-and-drops`](flow-logs-and-drops/) | Observability |
| [`pod-identity-and-l7`](pod-identity-and-l7/) | Network Security & Policy |

## Domain weights and current coverage

| Domain | Weight | Coverage today |
|---|---|---|
| [Core Infrastructure & CNI](01-core-cni/) | 15% | Partial — 3 of 5 built |
| [Service Networking & DNS](02-services-and-dns/) | 25% | Partial — 2 of 4 built |
| [Advanced Traffic Management](03-traffic-management/) | 20% | Partial — 1 of 4 built |
| [Network Security & Policy](04-security-and-policy/) | 25% | Partial — 2 of 3 specs built, plus the `netpol/` labs below |
| [Observability](05-observability/) | 15% | Partial — 1 of 3 built |

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

## Confirmed: the backend runs Cilium with kube-proxy replacement

Established by running `packet-path-with-linux-tools` on the real `kubernetes-kubeadm-1node` backend. There is
**no `kube-proxy` DaemonSet and no `KUBE-` iptables chains at all** — `cilium`, `cilium-envoy` and
`cilium-operator` only, with `Socket LB: Enabled`.

The practical consequence, and it bites: **Service translation happens inside the `connect()` syscall, before a
packet exists.** A `tcpdump` on the client's veth shows the backend Pod IP and target port from the first SYN;
the ClusterIP never appears on the wire, and `iptables-save -t nat` is empty. Any lab that assumes the
kube-proxy datapath — a ClusterIP visible in a capture, a `DNAT` rule to find, a translation to observe
in flight — is wrong here and will fail its own verification.

Labs touching Services must either handle both datapaths or state which one they require. The service map is
readable with `cilium-dbg service list`, which holds exactly the mapping the iptables chain would have.

**Two capabilities confirmed available, against a cluster reproducing that exact configuration:**

- **Hubble flow logs need nothing installed.** Hubble is enabled *in the agent* by default
  (`Hubble: Ok ... Flows/s: 6.95`), and `hubble observe` works inside the `cilium` Pod.
  `hubble-relay` is absent from the backend and is not required — relay only aggregates across nodes,
  and there is one node. This is what [`flow-logs-and-drops`](flow-logs-and-drops/) runs on.
- **L7 policy is enforced.** `cilium-envoy` runs as its own DaemonSet, and `CiliumNetworkPolicy` with
  `toPorts.rules.http` genuinely discriminates by method and path on one port — `GET /hostname` → 200,
  `GET /` → 403, `POST /hostname` → 403. This unblocks
  [`pod-identity-and-l7`](pod-identity-and-l7/), now built.

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
4. ~~**`02-services-and-dns/httproute-in-depth`**~~ — **built** as
   [`httproute-in-depth`](httproute-in-depth/), against a real Envoy Gateway controller rather than an inert
   object graph: `sectionName` listener attachment, match precedence, measured weighted splitting, and the
   two separate namespace boundaries (`allowedRoutes` vs `ReferenceGrant`) the original design spec conflated
   into one.
5. ~~**`04-security-and-policy/gateway-tls`**~~ — **built** as [`gateway-tls`](gateway-tls/): a self-signed
   CA via `cert-manager`, SNI serving two certificates off one port, a forced renewal the `Gateway` never had
   to be told about, and `Passthrough` mode's `supportedKinds` refusing `HTTPRoute` outright rather than
   merely failing to route it.
   > Correction to the roadmap's earlier "four `Ready` security labs" claim: only this one was actually marked
   > `Ready` in its `PLANNED.md`. `pod-identity-and-l7` and `transparent-encryption` are both `Verify first` —
   > see the coverage table above.
6. ~~**`01-core-cni/pod-connectivity-triage`**~~ — **built** as
   [`packet-fault-triage`](packet-fault-triage/): four faults that are
   indistinguishable from the client — a silent `FORWARD` drop, a missing return route, an `nft` rule
   `iptables -L` cannot see, and a PMTU black hole. Runs in network namespaces on the `ubuntu` backend rather
   than a cluster, deliberately: no CNI or kube-proxy to hide behind. Its spec's open question — whether faults
   could be injected reproducibly without wedging the node — is answered by never touching the host's stack.
7. ~~**`03-traffic-management/llm-routing`**~~ — **built** as [`llm-routing`](llm-routing/), opening the
   20%-weight domain that had no coverage at all: a streaming answer truncated by Envoy's 15s default while
   still logging `200`, round-robin sending work to a replica with a ten-deep queue while another sits idle,
   **least-request failing to fix it** (it counts what the proxy dispatched, not what the model server queued),
   and the model name living in the JSON body where `HTTPRoute` structurally cannot match on it.
8. ~~**`05-observability/flow-logs-and-drops`**~~ — **built** as
   [`flow-logs-and-drops`](flow-logs-and-drops/), opening Observability: security identities rather than
   addresses, a default-deny whose verdict is `policy-verdict:none` because *no rule fired*, a `scanner`
   nobody authorised discovered from the flow log, and an allow-list derived from traffic that actually
   happened.
9. ~~**`04-security-and-policy/pod-identity-and-l7`**~~ — **built** as
   [`pod-identity-and-l7`](pod-identity-and-l7/): what native NetworkPolicy structurally cannot say, the
   `403`-versus-`000` distinction that reveals which layer refused, the Envoy redirect that enforces it and
   what it costs, and two silent traps — a broad L4 allow unioning away a narrow L7 rule, and an `ipBlock`
   naming the correct Pod IP that matches nothing at all.
10. **Defer everything marked `Verify first`** until each has been individually checked against a live cluster.
11. **Treat cross-cluster as out of scope** unless nested clusters prove workable.

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
| [`ai-workloads/inference-sim`](../ai-workloads/inference-sim/) | Traffic Management | Built — its simulator is reused by [`llm-routing`](llm-routing/) |

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
