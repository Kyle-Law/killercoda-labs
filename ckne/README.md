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
| [`inference-gateway`](inference-gateway/) | Advanced Traffic Management |

## Domain weights and current coverage

| Domain | Weight | Coverage today |
|---|---|---|
| [Core Infrastructure & CNI](01-core-cni/) | 15% | Partial — 3 of 6 built |
| [Service Networking & DNS](02-services-and-dns/) | 25% | Partial — 2 of 10 built |
| [Advanced Traffic Management](03-traffic-management/) | 20% | Partial — 2 of 6 built |
| [Network Security & Policy](04-security-and-policy/) | 25% | Partial — 2 of 5 built, plus the `netpol/` labs below |
| [Observability](05-observability/) | 15% | Partial — 1 of 4 built |

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

## The Istio constraint is narrower than it looks

Five specs name Istio. **The blocker applies to two of them, not five** — a distinction established
by a runbook that ran Istio successfully on a kubeadm + Cilium cluster of the same shape as this
backend.

Cilium's documentation says `kubeProxyReplacement` disrupts Istio because it enables socket-based
load balancing *inside Pod network namespaces*, and this backend is confirmed running exactly that
with `Socket LB Coverage: Full`. But read what it disrupts: **sidecar proxies and the ambient node
proxy**. A gateway-only Istio install has neither. The gateway is a standalone Envoy that receives
endpoints from pilot rather than resolving a ClusterIP, so socket LB never enters its path.

| Spec | Needs | Status |
|---|---|---|
| [`inference-gateway`](inference-gateway/) | Istio as gateway only | **Not blocked** — proven on kubeadm + Cilium |
| [`gateway-api-portability`](02-services-and-dns/gateway-api-portability/) | Istio as gateway only | Not blocked, if Istio is the second controller |
| [`tracing-with-jaeger`](05-observability/tracing-with-jaeger/) | depends on scope | Not blocked if gateway-scoped; blocked if it needs per-hop spans from a mesh |
| [`istio-peer-authentication`](04-security-and-policy/istio-peer-authentication/) | a real data plane | **Blocked** — mTLS between workloads needs sidecars or ambient |
| [`istio-authorization-policy`](04-security-and-policy/istio-authorization-policy/) | a real data plane | **Blocked** — same |

For the two that are genuinely blocked, the fix is known and the failure mode is the dangerous kind:
sidecars inject, Pods go Ready, traffic flows, and anything depending on *Service* identity stops
working silently — the same shape as the kube-proxy surprise that broke
[`packet-path-with-linux-tools`](packet-path-with-linux-tools/) after it shipped. Cilium requires
`socketLB.hostNamespaceOnly: true` and `cni.exclusive: false`;
[`cni-install-and-configure`](cni-install-and-configure/) already installs Cilium with chosen Helm
values, so that spike has somewhere to start.

> **A Gateway *can* reach `Programmed=True` here after all.** The note elsewhere in this file — that
> no load-balancer controller exists, so the data-plane Service never gets an address — is escapable:
> `networking.istio.io/service-type: NodePort` on the Gateway makes Istio expose it as a NodePort
> instead, and it programs. That is an Istio-specific annotation; Envoy Gateway needs its own
> equivalent, which is why the labs built on it still gate on `Accepted`.

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
10. ~~**`03-traffic-management/inference-gateway`**~~ — **built** as
    [`inference-gateway`](inference-gateway/), the sequel to `llm-routing` and the first lab
    built from a working runbook rather than from a spec: the endpoint picker scores replicas on
    prefix cache, queue depth and KV usage weighted 3/2/2, so a replica holding the prefix with
    eight requests queued scores 5 against an idle replica's 4 — **queue depth is measured,
    scored, and structurally unable to win**. Changing one integer inverts it, and the chart
    silently reverts that integer on the next upgrade.
11. **Defer everything marked `Verify first`** until each has been individually checked against a live cluster.
12. **Treat cross-cluster as out of scope** unless nested clusters prove workable.

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

**Every check must say what it wanted.** Killercoda decides pass/fail from the verify script's exit code alone and
never shows the learner its output, so a bare `exit 1` is silent by construction — a red cross and nothing else.
Each `verify.sh` therefore writes its reason to `/root/.check`, and every lab's init installs a `why` helper that
prints it:

```bash
LOG=/root/.check
STEP="Step 1 · ..."
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
```

Name the condition that was not met, include the live state behind it (what the field actually says, what came
back on the wire), and give the command that shows it. State the criterion without handing over the answer the
step is asking for. Where a check waits in a retry loop, record which condition it is still waiting on and report
that one when the attempts run out. Each step's text carries a line pointing at `why`.

**`mkdir -p /root/answers` in the init if any step writes a finding there.** Two labs shipped without it, and both
were unpassable at those steps: the learner's redirect failed with `No such file or directory` and the check said
nothing.

> **An Envoy Gateway `Gateway` does not reach `Programmed=True` here by default.** There is no load-balancer
> controller, so the data-plane Service gets no external address — `AddressNotAssigned` — while serving perfectly
> on its ClusterIP. Gate on `Accepted` and on the Service's ClusterIP existing; a `Programmed` gate makes the step
> impossible to pass.
>
> This is a property of how the Service is requested, not of the backend: Istio's
> `networking.istio.io/service-type: NodePort` annotation makes it a NodePort instead, and the Gateway then
> programs — see [the Istio section above](#the-istio-constraint-is-narrower-than-it-looks). Envoy Gateway needs
> its own equivalent, which the labs built on it do not currently use.

## Reconciled against the curriculum's sub-topics

The roadmap has been reconciled against the 22 sub-topics of the five domains, each with its mapped
technology. Every spec now carries a **Mapped tech** row naming what the sub-topic expects, because
several objectives name two technologies that are not interchangeable — `egress-gateway` is Cilium's
datapath SNAT *and* Istio's proxy hop, `transparent-encryption` and
[`istio-peer-authentication`](04-security-and-policy/istio-peer-authentication/) are two halves of one
objective, and [`pod-identity-and-l7`](pod-identity-and-l7/) and
[`istio-authorization-policy`](04-security-and-policy/istio-authorization-policy/) likewise.

**Domain folders stay the organising axis, not technology.** A technology axis would duplicate —
`gateway-api-portability` is four implementations, `egress-gateway` is two — and it would push
scenarios past the two-level indexing limit described above.

**Two objectives are currently claimed by two specs each, and one of each pair has to give way:**

- *Troubleshooting E2E Network Performance with Tracing* —
  [`latency-attribution`](05-observability/latency-attribution/) and
  [`tracing-with-jaeger`](05-observability/tracing-with-jaeger/). The second is the one that matches
  the mapped technology; the first predates the reconciliation and should either be absorbed into it
  or re-scoped to metrics-based attribution, which no spec currently owns outright.
- *Troubleshooting Service Network Traffic* —
  [`traffic-policy-and-source-ip`](02-services-and-dns/traffic-policy-and-source-ip/) and
  [`service-traffic-triage`](02-services-and-dns/service-traffic-triage/). The first is really about
  `externalTrafficPolicy` and arguably belongs under *Configuring L4 Services*; the second is the
  triage lab the objective describes.

Resolve both before building either pair, so two labs are not written against the same sub-topic.

> Reconciled from a supplied domain outline with per-sub-topic technology mappings. Treat the
> weightings as authoritative for build order; check the objective titles against the published
> CNCF document before quoting them in lab text.
