
<br>

**Native `NetworkPolicy` has no vocabulary for methods or paths.** `ingress.from` offers `podSelector`, `namespaceSelector` and `ipBlock`; `ingress.ports` offers `port`, `protocol` and `endPort`. "Refuse POST" is not badly written in that API — it is unwriteable. Everything above L4 has to go somewhere else: the application, a sidecar, or a CNI that extends the model.

**`000` and `403` are different layers answering.** A dropped packet produces no response at all — the silent failure the `netpol/` labs exist to teach. A `403` means the connection was established, the request was parsed, and its *contents* were judged. Reading that distinction off a status code tells you immediately which kind of policy you are up against.

**A broad L4 allow silently defeats every narrower L7 rule for the same traffic.** NetworkPolicy is allow-only and additive — policies never restrict each other, they union. An unconditional `api-l4` permitting `web -> api:8080` and an `api-l7` permitting only `GET /hostname` on that same port means a `POST` fails the second and satisfies the first, and one match is all it needs. The L7 policy is accepted, loaded, and its proxy redirect genuinely programmed; it simply grants nothing the other rule had not already granted. Removing the broader grant is what makes the narrower one bite.

**L7 enforcement means a proxy in the datapath, and `cilium-dbg status --verbose` names it.** `cilium-http-ingress 2119:ingress:TCP:8080:` — traffic to that endpoint on that port is redirected into Envoy. Measured here at roughly 1.5–2× per-request latency, a few hundred microseconds on a single node. The absolute figure is small enough to be meaningless on its own; what generalises is that you have added a userspace round trip to every request the rule matches. Scope L7 rules tightly, because a broad selector puts the proxy in front of everything it catches.

**An `ipBlock` rule naming the correct Pod IP matches nothing, silently.** Cilium resolves in-cluster Pod traffic to a label-derived identity; a CIDR selector resolves to a different, CIDR-derived one. The rule is accepted, stored, returned by `kubectl get netpol`, and translated into the datapath — and never fires. Hubble reports `policy-verdict:none`. Changing only the selector from `ipBlock` to `podSelector`, with every other field identical, turns `000` into `200`.

That is worth generalising beyond this one API: **a NetworkPolicy that is accepted is not a NetworkPolicy that does anything.** The same lesson as a policy applied on a CNI with no enforcement at all — it just fails in a narrower, more surprising way.

**Label-based rules survive Pod churn for free.** Restart the Deployment: new Pod, new address, same identity, policy unchanged and still correct. `ipBlock` remains the right tool for traffic from outside the cluster, where there is no Pod to select.

## Where to go next

- [`ckne/flow-logs-and-drops`](../flow-logs-and-drops/) — where `policy-verdict:none` comes from, and how to see every verdict as it happens
- [`netpol/allow-only-and-default-deny`](../../netpol/allow-only-and-default-deny/) — the native API's semantics in full, and why allow-only is how you block things
- [`netpol/egress-and-the-dns-trap`](../../netpol/egress-and-the-dns-trap/) — the same L3/L4 model applied to egress, and the outage it causes

> `ckne/README.md` — this lab covers the CKNE "Implementing Pod-level Authentication and Authorization" objective in Network Security & Policy.
