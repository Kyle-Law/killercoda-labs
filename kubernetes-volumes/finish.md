
<br>

### Recap

- **emptyDir** — shared scratch space between containers in a Pod, gone when the Pod leaves the node.
- **hostPath** — exposes the node's own filesystem; survives Pod restarts but ties you to that one node and breaks portability.
- **Static PV/PVC** — storage with a lifecycle independent of any Pod; an admin provisions the PV ahead of time, and it typically uses reclaim policy `Retain`.
- **StorageClass** — the cluster provisions PVs for you on demand; dynamically created volumes default to reclaim policy `Delete`, so deleting the claim deletes the data too.
- **ConfigMap / Secret volumes** — project config and sensitive data into a Pod as files, and unlike env vars, a mounted ConfigMap volume updates live without a Pod restart.

### WELL DONE!

You've worked through the full range of Kubernetes volume types, from ephemeral to persistent to injected configuration.
