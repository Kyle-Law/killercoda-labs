
<br>

Every object in the cluster — every Pod, Secret, ConfigMap, everything — lives in `etcd`. "Implement etcd backup and restore" is explicit CKA Cluster Architecture content, and it's one of the few skills on the exam where getting it wrong for real would be catastrophic — which is exactly why it's tested.

On kubeadm, `etcd` runs as a static Pod with `hostNetwork: true`, so its client port (`2379`) is reachable directly from the node's own shell — no need to exec into any container. This lab won't assume `etcdctl` is already on your `PATH`; if it's missing, install it yourself, matching the version the running `etcd` container was built from (check its image tag).

> The golden rule of etcd restore: **never restore over the live data directory.** Always restore into a fresh one and repoint the static Pod manifest at it. That way, if anything goes wrong, the original data is still sitting untouched at `/var/lib/etcd`.
