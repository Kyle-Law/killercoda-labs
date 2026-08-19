
<br>

### Recap

- **StorageClass** — defines *how* storage gets provisioned. A PVC that omits `storageClassName` uses the cluster's default and gets a `PersistentVolume` created for it on demand, no admin involved.
- **Reclaim policy** — dynamically provisioned volumes default to `Delete`, so removing the claim removes the backing volume and its data. Statically provisioned PVs typically use `Retain` instead, keeping data until an admin cleans it up.
- **ConfigMap / Secret volumes** — each key becomes a file in the mount directory. Unlike environment variables, which are snapshotted at container start, a mounted ConfigMap volume syncs updates into an already-running Pod.

### WELL DONE!

Combined with Part 1, you've covered the full range of Kubernetes volume types — ephemeral, node-local, persistent, dynamically provisioned, and configuration-injected.
