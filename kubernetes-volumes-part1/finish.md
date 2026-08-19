
<br>

### Recap

- **emptyDir** — shared scratch space between containers in a Pod, gone when the Pod leaves the node.
- **hostPath** — exposes the node's own filesystem; survives Pod restarts but ties you to that one node and breaks portability.
- **Static PV/PVC** — storage with a lifecycle independent of any Pod. An admin provisions the PV ahead of time, a PVC binds to it by matching capacity, access modes, and `storageClassName`, and reclaim policy `Retain` keeps the data after the claim is deleted.

### WELL DONE!

Hand-provisioning a PV for every claim doesn't scale. **Part 2** picks up there: letting the cluster create volumes on demand with a `StorageClass`, plus mounting `ConfigMaps` and `Secrets` as volumes.
