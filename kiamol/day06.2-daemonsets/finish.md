
<br>

### Recap

- There's no `kubectl create daemonset` — generate a Deployment with `--dry-run=client -o yaml` and hand-edit it, or write the YAML directly.
- Taints block a DaemonSet's Pods exactly like any other Pod's — a `toleration` on the Pod template is what gets it scheduled, without ever touching the taint itself.
- `nodeSelector` is evaluated by the DaemonSet controller directly. An unmatched node isn't a `Pending` Pod waiting for something — it's never a candidate at all, so `desired` reflects reality rather than intent.
- `updateStrategy: OnDelete` decouples "the spec changed" from "the Pods changed." `RollingUpdate` (the default) propagates automatically; `OnDelete` hands you exact control over when each node picks up the new version.

### WELL DONE!

Every one of these behaviors is specific to DaemonSets — a Deployment's ReplicaSet doesn't reason about individual nodes at all, which is exactly why DaemonSets exist as their own controller instead of just being "a Deployment with a big replica count."
