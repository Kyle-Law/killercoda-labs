
<br>

DaemonSets have their own mechanics that don't come up anywhere else: there's no `kubectl create daemonset` command, "desired" can legitimately be zero without anything being wrong, and node scheduling constraints (taints, `nodeSelector`) affect a DaemonSet's own reconciliation loop directly — not just the default scheduler.

This cluster has **two nodes**, deliberately — a DaemonSet's whole point disappears on a single-node cluster, since "one Pod per node" and "one Pod total" become indistinguishable.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
