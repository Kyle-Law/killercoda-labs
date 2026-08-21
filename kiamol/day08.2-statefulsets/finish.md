
<br>

### Recap

- The default `OrderedReady` policy means each ordinal must be fully `Ready` — not just `Running` — before the next one is even created. That's a much stronger guarantee than a ReplicaSet gives you, and the reason clustered apps that need a primary-before-secondaries startup sequence reach for StatefulSets specifically.
- A PVC from `volumeClaimTemplates` is tied to an ordinal, not to any one Pod object or even to the current replica count. Scale down, scale back up, delete the whole StatefulSet — the claim (and its data) survives all three.
- `updateStrategy.rollingUpdate.partition` freezes every ordinal below the given number, turning a rolling update into a manual, ordinal-by-ordinal canary — no separate tooling needed.
- Only `replicas`, `template`, and `updateStrategy` can be changed on a live StatefulSet. Everything else, `volumeClaimTemplates` included, means delete and recreate — which is safe specifically *because* PVCs don't belong to the StatefulSet's cascade.

### WELL DONE!

Every one of these exists to give a genuinely stateful, ordered application the guarantees a Deployment can't make — identity, storage, and rollout control that all outlive the controller itself.
