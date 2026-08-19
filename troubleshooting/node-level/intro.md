
<br>

Three failures that all show up as "something's wrong with the node," each needing a different fix:

1. The node *looks* healthy but isn't accepting new work
2. The node is genuinely unhealthy — the kubelet agent itself has stopped
3. The kubelet is running but can't talk to the API server

Steps 2 and 3 happen on the node's own OS, outside Kubernetes entirely — `systemctl` and `journalctl`, not `kubectl`.
