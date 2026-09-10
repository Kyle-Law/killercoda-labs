
<br>

**A `Gateway` is infrastructure a platform team owns; an `HTTPRoute` is one team's routing intent, opted into a specific listener.** `sectionName` on `parentRefs` picks exactly which listener a route attaches to — a route never attaches to "the Gateway" as a whole, only to a named listener on it. Two listeners on one Gateway can serve the same hostname to completely different backends, with no overlap, purely because of which one a route named.

**`Gateway` status has two levels, and they answer different questions.** The top-level `Programmed` condition is about whether an external address was assigned — meaningless without a cloud load balancer, and `False` on every cluster that doesn't have one. `status.listeners[].conditions` is where "will traffic actually flow" lives. Reading the wrong one turns a working Gateway into a mystery.

**Rule order in the YAML decides nothing.** Precedence is specificity: an exact path beats a prefix, and among rules with equal path specificity, one that also matches on a header or a method beats one that doesn't — regardless of which rule was written first or listed first. A narrowly-targeted canary rule is always checked ahead of the broad rule sitting next to it in the file.

**A weighted split is a target, not a per-request guarantee.** 200 independent requests landing near 80/20 rather than exactly on it is the split working correctly — the same way 200 coin flips don't land on precisely 100 heads. Don't judge a weighted rollout from a handful of manual requests; there isn't enough volume in the sample to mean anything yet.

**There are two separate namespace boundaries, enforced at two separate points, and Ingress needed neither.** A listener's `allowedRoutes` decides whose *routes* may attach to it at all — checked before anything else, rejected as `NotAllowedByListeners` if it fails. `ReferenceGrant` decides whose *backends* an already-attached route may point at — checked afterward, rejected as `RefNotPermitted`, and it lives in the **target** namespace, naming the **source** namespace it trusts. Both fail the same way from the outside: `kubectl apply` succeeds, nothing looks wrong in the object graph, and the first real symptom is a `500` with no explanation in the response. `status.parents[].conditions` is the only place that says which boundary actually stopped it.

## Where to go next

- [`networking/ingress-and-gateway-api`](../../networking/ingress-and-gateway-api/) — the same objects with no controller behind them, useful for the shape alone without needing a working data plane
- [`ckne/coredns-customization`](../coredns-customization/) — DNS for the hostnames a `Gateway` matches against is configured the same way regardless of which controller reads the routes
- [`netpol/allow-only-and-default-deny`](../../netpol/allow-only-and-default-deny/) — a NetworkPolicy in front of `web` would need to allow ingress from Envoy's Pods specifically, not from "the internet" — worth working out why before assuming a Gateway and a default-deny policy compose for free

> `ckne/README.md` — this lab covers the CKNE "Managing Traffic with the Gateway API" objective in Service Networking & DNS, and is a stated prerequisite for `ckne/04-security-and-policy/gateway-tls`.
