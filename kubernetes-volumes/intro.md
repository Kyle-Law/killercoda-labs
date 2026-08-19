
<br>

An exam-style progression through Kubernetes volume types, ordered from simplest to most involved:

1. **emptyDir** — ephemeral scratch space shared between containers in a Pod
2. **hostPath** — mounting a path from the node's own filesystem
3. **Static PersistentVolume / PersistentVolumeClaim** — an admin-provisioned volume with a lifecycle independent of any Pod
4. **StorageClass** — dynamic provisioning, PVs created on demand
5. **ConfigMap / Secret volumes** — projecting config and sensitive data into a Pod as files, including a live update

Each step states a task, not a solution. Work it out yourself first — a **Tip** dropdown points at the relevant `kubectl explain`/`--help`, and a **Solution** dropdown has the full answer if you get stuck. Every step is graded automatically against the real cluster state, so partial or alternative approaches that meet the same end state will pass too.
