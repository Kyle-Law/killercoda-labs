
<br>

Four StatefulSet behaviors that don't come up anywhere else in Kubernetes: creation ordering is gated on **readiness**, not just existence; a PVC's lifecycle is decoupled from both the Pod's and the replica count; a rolling update can be frozen at a specific ordinal; and the StatefulSet spec itself is far more locked-down than a Deployment's.

One `db` StatefulSet runs through all four steps — each step changes it, rather than starting fresh, so watch how state (and data) survives across the whole lab.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
