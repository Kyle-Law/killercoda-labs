
<br>

**Part 2 of 2.** Storage the cluster manages for you, plus injecting configuration as files:

1. **StorageClass** — dynamic provisioning, `PersistentVolumes` created on demand
2. **ConfigMap / Secret volumes** — projecting config and sensitive data into a Pod as files, including a live update with no Pod restart

Each step states a task, not a solution. Work it out yourself first — a **Tip** dropdown points at the relevant `kubectl explain`/`--help`, and a **Solution** dropdown has the full answer if you get stuck. Every step is graded automatically against real cluster state, so alternative approaches that reach the same end state pass too.

> Part 1 covers `emptyDir`, `hostPath`, and manually provisioned PV/PVCs. This lab is fully standalone — you can take it before or after that one.
