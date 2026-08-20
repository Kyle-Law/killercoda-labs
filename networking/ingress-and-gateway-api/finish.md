
<br>

### Recap

| | Ingress | Gateway API |
|---|---|---|
| Objects | one `Ingress` | `GatewayClass` (cluster-scoped, defines the controller) → `Gateway` (a listener) → `HTTPRoute` (the actual routing rules, often owned by app teams) |
| Who owns what | usually one team writes the whole `Ingress` | roles are split — infra owns the `Gateway`, app teams attach `HTTPRoute`s to it |
| Expressiveness | path/host rules only, everything else is controller-specific annotations | header/method matching, traffic splitting/weighting, and more, as first-class typed fields |

### WELL DONE!

Same routing intent, two different object models — and per the current curriculum, you're expected to be fluent in both, not just the newer one.
