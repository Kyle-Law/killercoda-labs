
<br>

### Recap

| Layer | What it is |
|---|---|
| **CRDs** | New object types (`Prometheus`, `ServiceMonitor`, ...) registered with the API server — `kubectl explain` works on them like any built-in |
| **Operator** | An ordinary Deployment whose controller watches those custom resources and reconciles them into real objects |
| **Custom resource** | Your declaration of intent (`kind: Prometheus`) — the operator turned it into a StatefulSet you never wrote |
| **ServiceMonitor** | Scrape config as a Kubernetes object, picked up dynamically — no config file editing, no Prometheus restart |

### WELL DONE!

Two RBAC identities were involved and they're easy to confuse: the **operator's** ServiceAccount (installed by the bundle, manages custom resources) and **Prometheus's own** ServiceAccount (you created it, needs cluster-wide read access to discover scrape targets). A Prometheus that starts but scrapes nothing is very often the second one missing.

This is the same shape as every other operator you'll meet — cert-manager, Elastic, Postgres operators all work exactly this way.
