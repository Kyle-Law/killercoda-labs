
<br>

### Recap

- A ConfigMap consumed via `envFrom` is read **once**, when the container starts. Updating the ConfigMap doesn't touch running Pods, and Helm has no reason to restart them because the Deployment spec itself didn't change.
- `kubectl rollout restart` fixes it manually, but that's a step someone has to remember.
- The `checksum/config` annotation solves it properly: it puts a hash of the ConfigMap into the **Pod template**, so any config change alters the template and Kubernetes rolls the Deployment on its own.

### WELL DONE!

For the same behaviour without editing charts, look at [Reloader](https://github.com/stakater/Reloader), which watches ConfigMaps and Secrets and restarts the workloads that use them.
