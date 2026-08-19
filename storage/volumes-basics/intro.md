
<br>

**Part 1 of 2.** Storage you manage by hand, from simplest to most involved:

1. **emptyDir** — ephemeral scratch space shared between containers in a Pod
2. **hostPath** — mounting a path from the node's own filesystem
3. **Static PersistentVolume / PersistentVolumeClaim** — an admin-provisioned volume with a lifecycle independent of any Pod

Each step states a task, not a solution. Work it out yourself first — a **Tip** dropdown points at the relevant `kubectl explain`/`--help`, and a **Solution** dropdown has the full answer if you get stuck. Every step is graded automatically against real cluster state, so alternative approaches that reach the same end state pass too.

> Part 2 covers dynamic provisioning with `StorageClass` plus `ConfigMap` and `Secret` volumes. It's fully standalone — you can take it before or after this one.
