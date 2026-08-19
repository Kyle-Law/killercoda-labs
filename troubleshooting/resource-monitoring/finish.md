
<br>

### Recap

- `kubectl top pod` / `kubectl top node` need `metrics-server` — not installed by default on kubeadm, and on kubeadm specifically it needs `--kubelet-insecure-tls` to trust the cluster's self-signed kubelet certs.
- A `ResourceQuota` caps total requests/limits across a namespace — a Deployment can look perfectly healthy and still get `0` Pods scheduled if quota blocks every replica.
- `kubectl top pod --sort-by=cpu|memory` turns "something is using too many resources" into a specific Pod name, fast.

### WELL DONE!

That closes out the CKA Troubleshooting domain across this set of labs: Pods, control plane, Services/DNS, nodes, RBAC, and resource usage.
