
<br>

### Recap

- Kubernetes RBAC binds to a **name**, not an object — `Kind: User` and `Kind: Group` subjects work exactly like `Kind: ServiceAccount`, just without a Kubernetes object backing them. The name comes from whatever authenticated the request (a client certificate's CN, an OIDC claim, etc.).
- `kubeadm certs renew <cert-name>` renews one certificate's file on disk; the running static Pod won't pick it up until it restarts.
- `kubeadm token create` is how new nodes join a cluster after the initial `kubeadm init` — tokens are short-lived by design (`--ttl`), unlike the long-lived certs used for ongoing cluster communication.

### WELL DONE!

Combined with the etcd backup/restore lab, that covers the day-to-day and disaster-recovery ends of Cluster Architecture maintenance.
