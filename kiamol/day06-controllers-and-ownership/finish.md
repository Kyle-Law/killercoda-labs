
<br>

### Recap

- A bare ReplicaSet behaves exactly like a Deployment's — because a Deployment's ReplicaSet *is* just a ReplicaSet, with an extra owner on top.
- Changing `replicas` updates a ReplicaSet in place. Changing anything in the Pod `template` makes a Deployment create a **new** ReplicaSet and scale the old one to zero — never delete it, which is what makes `kubectl rollout undo` instant.
- `--cascade=orphan` detaches a controller from its Pods without touching them. Recreating a matching controller re-adopts them via the label selector — Kubernetes doesn't track "this Pod belongs to this specific controller instance," only "does this Pod's labels match my selector."

### WELL DONE!

Every controller in Kubernetes — ReplicaSet, DaemonSet, StatefulSet, Job — follows this same ownership model: a label selector finds the Pods, and `ownerReferences` records who's responsible for them.
