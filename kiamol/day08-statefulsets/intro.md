
<br>

Based on *Learn Kubernetes in a Month of Lunches*, Day 8 — "Running data-heavy apps with StatefulSets and Jobs."

A ReplicaSet gives every Pod a random name and treats them as interchangeable. Clustered, stateful applications (databases, message queues) usually can't work that way — they need a stable identity, individually addressable Pods, and independent storage per instance. A `StatefulSet` provides all three.

This lab covers StatefulSets specifically — Jobs and CronJobs from the same chapter are covered separately in `workloads/deployments-and-jobs`.
