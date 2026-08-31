
<br>

### Recap

- `argocd app history` records one entry per sync operation — but the table itself only shows the ID, timestamp, and source revision. It does not show which Helm parameters (or values files) were in effect at that sync. To see that, you have to read `.status.history[].source.helm.parameters` on the Application object directly.
- `argocd app rollback <id>` is append-only, exactly like `helm rollback`: it doesn't erase or rewind history, it creates a **new** entry that reapplies an old one's content.
- Unlike `helm rollback`, an Argo CD rollback does **not** update the Application's own `spec.source` — it's a one-time sync to old content, not a change to desired state. The Application immediately shows `OutOfSync` against its own unchanged spec, and the very next sync (manual or automated) reapplies the *current* spec, silently undoing the rollback.
- To make a rollback stick, update the spec to match what you rolled back to — `argocd app set --helm-set <param>=<old value>` — so the "current" desired state and the rolled-back live state agree. Only then does it survive a resync.

### WELL DONE!

`helm rollback` changes what the release *is*. `argocd app rollback` only changes what the cluster *has*, for as long as nothing reconciles it — which, on an actively-managed Application, is not long at all.
