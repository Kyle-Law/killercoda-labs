
<br>

### Recap

- `etcd` on kubeadm uses `hostNetwork: true` — its client port is reachable directly from the node, no container exec required.
- `etcdctl snapshot save` needs the same client certs the API server uses to talk to `etcd`, found in `etcd`'s own static Pod manifest.
- **Restore into a new data directory, never the live one.** Repoint the static Pod manifest's `hostPath` and `--data-dir` at the new location instead — the original data stays untouched as a fallback the whole time.
- Moving static Pod manifests out of `/etc/kubernetes/manifests/` stops them; moving them back starts them. That's the entire mechanism for safely pausing the control plane mid-restore.

### WELL DONE!

This is one of the highest-stakes procedures on the CKA exam — the same shape (snapshot, disaster, restore into a fresh directory) is exactly what you'd do against a real production cluster.
