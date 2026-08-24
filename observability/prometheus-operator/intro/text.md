
<br>

The **operator pattern** is how complex, stateful software gets managed in Kubernetes: instead of you writing Deployments and StatefulSets by hand, you install a controller that watches **custom resources** and builds the real objects for you. The Prometheus Operator is the canonical example — you declare `kind: Prometheus`, and it creates the StatefulSet, config, and Services behind it.

This lab installs the operator (pinned to `v0.93.1`), grants Prometheus the cluster-wide RBAC it needs to discover scrape targets, deploys Prometheus itself as a custom resource, and points it at a real workload with a `ServiceMonitor`.

**Two nodes**, deliberately: scrape-target discovery is only interesting when targets are spread across more than one machine.

> Heads up: the operator's bundle is a large manifest (10 CRDs plus the controller) and Prometheus itself pulls a sizeable image. The install steps take a few minutes — that's normal, not a hang.
