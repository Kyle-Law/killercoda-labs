
<br>

### Recap

- StatefulSet Pods get predictable, ordered names (`web-0`, `web-1`, ...). Replacing one recreates the same name with a new underlying object — identity is preserved, the object itself isn't.
- A headless Service (`clusterIP: None`) gives every Pod in the set its own DNS entry, so peers can address a specific instance instead of getting load-balanced to a random one.
- `volumeClaimTemplates` gives each replica an independent PVC, linked to that specific ordinal — replace `data-app-0` and the new Pod reattaches to `data-data-app-0`, not a fresh empty volume.

### WELL DONE!

These three features are exactly what a clustered, stateful app needs that a Deployment can't provide: stable names, individual addressability, and storage that follows the replica, not just the controller.
