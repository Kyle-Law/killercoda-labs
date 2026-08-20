
<br>

A Deployment doesn't manage Pods directly — it manages ReplicaSets, which manage Pods. Understanding that chain (and how Kubernetes tracks it via `ownerReferences`) explains behavior that otherwise looks strange: why scaling sometimes reuses a ReplicaSet and sometimes creates a new one, why deleted controllers don't always take their Pods with them, and why a stray label can silently break the whole relationship.
